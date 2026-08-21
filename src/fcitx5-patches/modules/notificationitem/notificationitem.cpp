/*
 * SPDX-FileCopyrightText: 2017-2017 CSSlayer <wengxt@gmail.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 *
 */

#include "notificationitem.h"
#include <cairo/cairo.h>
#include <unistd.h>
#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>
#include <utility>
#include <vector>
#include "fcitx-utils/charutils.h"
#include "fcitx-utils/dbus/message.h"
#include "fcitx-utils/dbus/objectvtable.h"
#include "fcitx-utils/dbus/servicewatcher.h"
#include "fcitx-utils/endian_p.h"
#include "fcitx-utils/eventloopinterface.h"
#include "fcitx-utils/handlertable.h"
#include "fcitx-utils/i18n.h"
#include "fcitx-utils/log.h"
#include "fcitx/addonfactory.h"
#include "fcitx/addoninstance.h"
#include "fcitx/addonmanager.h"
#include "fcitx/event.h"
#include "fcitx/icontheme.h"
#include "fcitx/inputmethodentry.h"
#include "fcitx/instance.h"
#include "fcitx/misc_p.h"
#include "fcitx/userinterface.h"
#include "classicui_public.h"
#include "dbus_public.h"
#include "dbusmenu.h"
#include "notificationitem_public.h"

#define NOTIFICATION_ITEM_DBUS_IFACE "org.kde.StatusNotifierItem"
#define NOTIFICATION_ITEM_DEFAULT_OBJ "/StatusNotifierItem"
#define NOTIFICATION_WATCHER_DBUS_ADDR "org.kde.StatusNotifierWatcher"
#define NOTIFICATION_WATCHER_DBUS_OBJ "/StatusNotifierWatcher"
#define NOTIFICATION_WATCHER_DBUS_IFACE "org.kde.StatusNotifierWatcher"
#define DBUS_MENU_IFACE "com.canonical.dbusmenu"
#define PIXMAP_ICON_DIR "/usr/share/icons/hicolor/"

#define SNI_DEBUG() FCITX_LOGC(::notificationitem, Debug)
#define SNI_ERROR() FCITX_LOGC(::notificationitem, Error)

namespace {

FCITX_DEFINE_LOG_CATEGORY(notificationitem, "notificationitem");

}

namespace fcitx {

class StatusNotifierItem : public dbus::ObjectVTable<StatusNotifierItem> {
public:
    StatusNotifierItem(NotificationItem *parent) : parent_(parent) {}

    void scroll(int delta, const std::string &_orientation) {
        std::string orientation = _orientation;
        std::ranges::transform(orientation, orientation.begin(),
                               charutils::tolower);
        if (orientation != "vertical") {
            return;
        }
        deltaAcc_ += delta;
        while (deltaAcc_ >= 120) {
            parent_->instance()->enumerate(true);
            deltaAcc_ -= 120;
        }
        while (deltaAcc_ <= -120) {
            parent_->instance()->enumerate(false);
            deltaAcc_ += 120;
        }
    }
    void activate(int /*unused*/, int /*unused*/) {
        parent_->instance()->toggle();
    }
    void secondaryActivate(int /*unused*/, int /*unused*/) {}
    std::string keyboardIconName() const {
        return "fcitx-wusong";
    }
    std::string iconName() {
        // 自定义雾凇图标：固定显示 fcitx-wusong（/usr/share/icons/hicolor/.../fcitx-wusong.*）
        // 想换图标只需替换该文件即可。
        return IconTheme::iconName("fcitx-wusong");
    }

    std::string iconNamePropertyImpl() {
        std::string label;
        std::string icon;
        if (auto *ic = parent_->menu()->lastRelevantIc()) {
            label = parent_->instance()->inputMethodLabel(ic);
            icon = parent_->instance()->inputMethodIcon(ic);
        }
        return preferTextIcon(label, icon) ? "" : iconName();
    }

    std::string label() { return ""; }

    std::string title() { return _("Input Method"); }

    dbus::DBusStruct<
        std::string,
        std::vector<dbus::DBusStruct<int32_t, int32_t, std::vector<uint8_t>>>,
        std::string, std::string>
    tooltip() {

        const InputMethodEntry *imEntry = nullptr;
        if (auto *ic = parent_->menu()->lastRelevantIc()) {
            imEntry = parent_->instance()->inputMethodEntry(ic);
        }
        std::string title =
            imEntry == nullptr ? _("Input Method") : imEntry->name();
        return {iconNamePropertyImpl(), iconPixmap(), std::move(title),
                std::string()};
    }

    bool preferTextIcon(const std::string &label,
                        const std::string &icon) const {
        auto *classicui = parent_->classicui();
        return classicui && !label.empty() &&
               ((icon == "input-keyboard" &&
                 classicui->call<IClassicUI::showLayoutNameInIcon>() &&
                 hasTwoKeyboardInCurrentGroup(parent_->instance())) ||
                classicui->call<IClassicUI::preferTextIcon>());
    }

    void notifyNewIcon() {
        auto icon = iconName();
        auto label = labelText();
        if (icon != lastIconName_ || label != lastLabel_) {
            newIcon();
            // https://github.com/ubuntu/gnome-shell-extension-appindicator/issues/468
            if (getDesktopType() == DesktopType::GNOME) {
                newOverlayIcon();
            }
        }
        lastIconName_ = std::move(icon);
        lastLabel_ = std::move(label);
    }

    void notifyNewTooltip() {
        auto currentTooltip = tooltip();
        const auto &tipTitle = std::get<2>(currentTooltip);
        if (tipTitle.empty() || lastTitle_ == tipTitle) {
            return;
        }
        newToolTip();
        lastTitle_ = tipTitle;
    }

    void reset() {
        releaseSlot();
        lastIconName_.clear();
        lastLabel_.clear();
    }

    std::string labelText() const {
        std::string label;
        std::string icon;
        if (auto *ic = parent_->menu()->lastRelevantIc()) {
            label = parent_->instance()->inputMethodLabel(ic);
            icon = parent_->instance()->inputMethodIcon(ic);
        }
        if (!preferTextIcon(label, icon)) {
            return "";
        }
        return label;
    }

    // Update the cached icon pixmap, return whether we have a valid icon.
    bool updateCachedIconPixmap() {
        auto *classicui = parent_->classicui();
        if (!classicui) {
            return false;
        }
        std::vector<dbus::DBusStruct<int, int, std::vector<uint8_t>>> result;
        const auto label = labelText();
        if (!label.empty() && cachedLabel_ != label) {
            for (unsigned int size : {16, 22, 32, 48}) {
                // swap to network byte order if we are little endian
                auto data = classicui->call<IClassicUI::labelIcon>(label, size);
                if (isLittleEndian()) {
                    auto *uintBuf = reinterpret_cast<uint32_t *>(data.data());
                    for (size_t i = 0; i < data.size() / sizeof(uint32_t);
                         ++i) {
                        *uintBuf = htobe32(*uintBuf);
                        ++uintBuf;
                    }
                }
                result.emplace_back(size, size, std::move(data));
            }
            cachedLabel_ = label;
            cachedLabelIcon_ = result;
        }
        return !cachedLabel_.empty();
    }

    std::vector<dbus::DBusStruct<int, int, std::vector<uint8_t>>> iconPixmap() {
        if (updateCachedIconPixmap()) {
            return cachedLabelIcon_;
        }
        return wusongIconPixmap();
    }

    // 加载自定义雾凇图标的位图（IconPixmap），避免依赖宿主图标主题查找
    const std::vector<dbus::DBusStruct<int, int, std::vector<uint8_t>>> &
    wusongIconPixmap() {
        if (!cachedWusongIcon_.empty()) {
            return cachedWusongIcon_;
        }
        for (unsigned size : {16u, 22u, 32u, 48u, 64u}) {
            std::string path = PIXMAP_ICON_DIR + std::to_string(size) + "x" +
                               std::to_string(size) +
                               "/apps/fcitx-wusong.png";
            cairo_surface_t *surface =
                cairo_image_surface_create_from_png(path.c_str());
            if (!surface ||
                cairo_surface_status(surface) != CAIRO_STATUS_SUCCESS) {
                if (surface) {
                    cairo_surface_destroy(surface);
                }
                continue;
            }
            auto format = cairo_image_surface_get_format(surface);
            if (format != CAIRO_FORMAT_ARGB32 &&
                format != CAIRO_FORMAT_RGB24) {
                cairo_surface_destroy(surface);
                continue;
            }
            int w = cairo_image_surface_get_width(surface);
            int h = cairo_image_surface_get_height(surface);
            auto *data = cairo_image_surface_get_data(surface);
            std::vector<uint8_t> pix(w * h * 4);
            if (format == CAIRO_FORMAT_RGB24) {
                // 无 alpha 的 PNG 会被解码为 RGB24：补齐不透明 alpha，
                // 并按网络字节序输出 A,R,G,B（SNI 要求）。
                for (int i = 0; i < w * h; ++i) {
                    pix[i * 4 + 0] = 0xFF;
                    pix[i * 4 + 1] = data[i * 4 + 2]; // R
                    pix[i * 4 + 2] = data[i * 4 + 1]; // G
                    pix[i * 4 + 3] = data[i * 4 + 0]; // B
                }
            } else { // CAIRO_FORMAT_ARGB32
                auto *dst = reinterpret_cast<uint32_t *>(pix.data());
                auto *src = reinterpret_cast<const uint32_t *>(data);
                for (size_t i = 0; i < static_cast<size_t>(w) * h; ++i) {
                    dst[i] = isLittleEndian() ? htobe32(src[i]) : src[i];
                }
            }
            cachedWusongIcon_.emplace_back(w, h, std::move(pix));
            cairo_surface_destroy(surface);
        }
        return cachedWusongIcon_;
    }

    FCITX_OBJECT_VTABLE_METHOD(scroll, "Scroll", "is", "");
    FCITX_OBJECT_VTABLE_METHOD(activate, "Activate", "ii", "");
    FCITX_OBJECT_VTABLE_METHOD(secondaryActivate, "SecondaryActivate", "ii",
                               "");
    FCITX_OBJECT_VTABLE_SIGNAL(newIcon, "NewIcon", "");
    FCITX_OBJECT_VTABLE_SIGNAL(newOverlayIcon, "NewOverlayIcon", "");
    FCITX_OBJECT_VTABLE_SIGNAL(newToolTip, "NewToolTip", "");
    FCITX_OBJECT_VTABLE_SIGNAL(newIconThemePath, "NewIconThemePath", "s");
    FCITX_OBJECT_VTABLE_SIGNAL(newAttentionIcon, "NewAttentionIcon", "");
    FCITX_OBJECT_VTABLE_SIGNAL(newStatus, "NewStatus", "s");
    FCITX_OBJECT_VTABLE_SIGNAL(newTitle, "NewTitle", "");
    FCITX_OBJECT_VTABLE_SIGNAL(xayatanaNewLabel, "XAyatanaNewLabel", "ss");

    FCITX_OBJECT_VTABLE_PROPERTY(category, "Category", "s",
                                 []() { return "SystemServices"; });
    FCITX_OBJECT_VTABLE_PROPERTY(id, "Id", "s", []() { return "Fcitx"; });
    FCITX_OBJECT_VTABLE_PROPERTY(title, "Title", "s",
                                 [this]() { return title(); });
    FCITX_OBJECT_VTABLE_PROPERTY(status, "Status", "s",
                                 []() { return "Active"; });
    FCITX_OBJECT_VTABLE_PROPERTY(windowId, "WindowId", "i", []() { return 0; });
    FCITX_OBJECT_VTABLE_PROPERTY(iconName, "IconName", "s",
                                 [this]() { return iconNamePropertyImpl(); });
    FCITX_OBJECT_VTABLE_PROPERTY(iconPixmap, "IconPixmap", "a(iiay)",
                                 ([this]() { return iconPixmap(); }));
    FCITX_OBJECT_VTABLE_PROPERTY(overlayIconName, "OverlayIconName", "s",
                                 ([]() { return ""; }));
    FCITX_OBJECT_VTABLE_PROPERTY(
        overlayIconPixmap, "OverlayIconPixmap", "a(iiay)", ([]() {
            std::vector<dbus::DBusStruct<int, int, std::vector<uint8_t>>>
                result;
            // workaround to
            // https://github.com/ubuntu/gnome-shell-extension-appindicator/issues/468
            // enforce the icon to have a invisible overlay icon to bypass an
            // optimization for pixmap in SNI extension.
            if (getDesktopType() == DesktopType::GNOME) {
                result.emplace_back(1, 1, std::vector<uint8_t>{0, 0, 0, 0});
            }
            return result;
        }));
    FCITX_OBJECT_VTABLE_PROPERTY(attentionIconName, "AttentionIconName", "s",
                                 []() { return ""; });
    FCITX_OBJECT_VTABLE_PROPERTY(
        attentionIconPixmap, "AttentionIconPixmap", "a(iiay)", ([]() {
            return std::vector<
                dbus::DBusStruct<int, int, std::vector<uint8_t>>>{};
        }));
    FCITX_OBJECT_VTABLE_PROPERTY(attentionMovieName, "AttentionMovieName", "s",
                                 []() { return ""; });
    FCITX_OBJECT_VTABLE_PROPERTY(tooltip, "ToolTip", "(sa(iiay)ss)",
                                 [this]() { return tooltip(); });
    FCITX_OBJECT_VTABLE_PROPERTY(itemIsMenu, "ItemIsMenu", "b",
                                 []() { return false; });
    FCITX_OBJECT_VTABLE_PROPERTY(menu, "Menu", "o",
                                 []() { return dbus::ObjectPath("/MenuBar"); });
    FCITX_OBJECT_VTABLE_PROPERTY(iconThemePath, "IconThemePath", "s",
                                 []() { return PIXMAP_ICON_DIR; });
    FCITX_OBJECT_VTABLE_PROPERTY(xayatanaLabel, "XAyatanaLabel", "s",
                                 [this]() { return label(); });
    FCITX_OBJECT_VTABLE_PROPERTY(XAyatanaLabelGuide, "XAyatanaLabelGuide", "s",
                                 [this]() { return label(); });
    FCITX_OBJECT_VTABLE_PROPERTY(xayatanaLabelOrderingIndex,
                                 "XAyatanaOrderingIndex", "u",
                                 []() { return 0; });
    FCITX_OBJECT_VTABLE_PROPERTY(iconAccessibleDesc, "IconAccessibleDesc", "s",
                                 []() { return _("Input Method"); });

private:
    NotificationItem *parent_;
    int deltaAcc_ = 0;
    std::string lastLabel_;
    std::string lastIconName_;
    // Quick cache for the icon.
    std::string cachedLabel_;
    std::vector<dbus::DBusStruct<int, int, std::vector<uint8_t>>>
        cachedLabelIcon_;
    std::string lastTitle_;
    // 自定义雾凇图标的位图缓存
    std::vector<dbus::DBusStruct<int, int, std::vector<uint8_t>>>
        cachedWusongIcon_;
};

NotificationItem::NotificationItem(Instance *instance)
    : instance_(instance),
      watcher_(std::make_unique<dbus::ServiceWatcher>(*globalBus())),
      sni_(std::make_unique<StatusNotifierItem>(this)),
      menu_(std::make_unique<DBusMenu>(this)) {
    reloadConfig();
    watcherEntry_ = watcher_->watchService(
        NOTIFICATION_WATCHER_DBUS_ADDR,
        [this](const std::string &, const std::string &,
               const std::string &newName) { setServiceName(newName); });
}

NotificationItem::~NotificationItem() = default;

dbus::Bus *NotificationItem::globalBus() {
    return dbus()->call<IDBusModule::bus>();
}

void NotificationItem::setServiceName(const std::string &newName) {
    SNI_DEBUG() << "Old SNI Name: " << sniWatcherName_
                << " New Name: " << newName;
    sniWatcherName_ = newName;
    // It's a new service anyway, set unregistered.
    setRegistered(false);
    SNI_DEBUG() << "Current SNI enabled: " << enabled_;
    maybeScheduleRegister();
}

void NotificationItem::setRegistered(bool registered) {
    // Always clean up if it's not registered.
    if (!registered) {
        cleanUp();
    }

    if (registered_ == registered) {
        return;
    }
    registered_ = registered;

    if (registered_) {
        auto updateIconAndTitle = [this](Event &e) {
            InputContext *ic = nullptr;
            if (e.isInputContextEvent()) {
                ic = dynamic_cast<InputContextEvent &>(e).inputContext();
            }
            menu_->updateMenu(ic);
            newIcon();
            newToolTip();
        };
        for (auto type : {EventType::InputContextFocusIn,
                          EventType::InputContextSwitchInputMethod,
                          EventType::InputMethodGroupChanged}) {
            eventHandlers_.emplace_back(instance_->watchEvent(
                type, EventWatcherPhase::Default, updateIconAndTitle));
        }
        eventHandlers_.emplace_back(instance_->watchEvent(
            EventType::InputContextFlushUI, EventWatcherPhase::Default,
            [updateIconAndTitle](Event &event) {
                if (static_cast<InputContextFlushUIEvent &>(event)
                        .component() == UserInterfaceComponent::StatusArea) {
                    updateIconAndTitle(event);
                }
            }));
    }

    for (auto &handler : handlers_.view()) {
        handler(registered_);
    }
}

void NotificationItem::registerSNI() {
    if (!enabled_ || sniWatcherName_.empty() || registered_) {
        return;
    }

    setRegistered(false);
    try {
        // Ensure we are released.
        privateBus_ = std::make_unique<dbus::Bus>(globalBus()->address());
    } catch (...) {
        setRegistered(false);
        return;
    }
    privateBus_->attachEventLoop(&instance_->eventLoop());
    // Add object before request name.
    privateBus_->addObjectVTable(NOTIFICATION_ITEM_DEFAULT_OBJ,
                                 NOTIFICATION_ITEM_DBUS_IFACE, *sni_);
    privateBus_->addObjectVTable("/MenuBar", DBUS_MENU_IFACE, *menu_);
    SNI_DEBUG() << "Current DBus Unique Name" << privateBus_->uniqueName();
    auto call = privateBus_->createMethodCall(
        sniWatcherName_.c_str(), NOTIFICATION_WATCHER_DBUS_OBJ,
        NOTIFICATION_WATCHER_DBUS_IFACE, "RegisterStatusNotifierItem");
    call << privateBus_->uniqueName();

    SNI_DEBUG() << "Register SNI with name: " << privateBus_->uniqueName();
    pendingRegisterCall_ = call.callAsync(0, [this](dbus::Message &msg) {
        // clear the pendingRegisterCall_, but keep it alive.
        std::unique_ptr<dbus::Slot> call = std::move(pendingRegisterCall_);
        SNI_DEBUG() << "SNI Register result: " << msg.signature();
        if (msg.signature() == "s") {
            std::string mesg;
            msg >> mesg;
            SNI_DEBUG() << mesg;
        }
        setRegistered(!msg.isError());
        return true;
    });
    privateBus_->flush();
}

void NotificationItem::maybeScheduleRegister() {
    if (!enabled_ || sniWatcherName_.empty() || registered_) {
        return;
    }
    // Try to avoid Race between close dbus and register.
    scheduleRegister_ = instance_->eventLoop().addTimeEvent(
        CLOCK_MONOTONIC, now(CLOCK_MONOTONIC) + 300000, 0,
        [this](EventSourceTime *, uint64_t) {
            registerSNI();
            return true;
        });
}

void NotificationItem::enable() {
    enabled_ += 1;
    if (enabled_ > 1) {
        return;
    }

    enabled_ = true;
    SNI_DEBUG() << "Enable SNI";
    maybeScheduleRegister();
}

void NotificationItem::disable() {
    instance_->eventDispatcher().scheduleWithContext(
        lifeTimeTracker_.watch(), [this]() {
            if (enabled_ == 0) {
                SNI_ERROR()
                    << "NotificationItem::disable called without enable.";
                return;
            }

            SNI_DEBUG() << "Disable SNI";
            enabled_ -= 1;
            if (enabled_ == 0) {
                setRegistered(false);
            }
        });
}

void NotificationItem::cleanUp() {
    pendingRegisterCall_.reset();
    sni_->reset();
    menu_->reset();
    privateBus_.reset();

    eventHandlers_.clear();
}

std::unique_ptr<HandlerTableEntry<NotificationItemCallback>>
NotificationItem::watch(NotificationItemCallback callback) {
    return handlers_.add(std::move(callback));
}

void NotificationItem::newIcon() {
    // Make sure we only call it when it is registered.
    if (!sni_->isRegistered()) {
        return;
    }
    sni_->notifyNewIcon();
    // Our label now is pixmap based, so no need to notify XAyatanaNewLabel.
    // sni_->xayatanaNewLabel(sni_->label(), sni_->label());
}

void NotificationItem::newToolTip() {
    if (!sni_->isRegistered()) {
        return;
    }
    sni_->notifyNewTooltip();
}

class NotificationItemFactory : public AddonFactory {
    AddonInstance *create(AddonManager *manager) override {
        return new NotificationItem(manager->instance());
    }
};

} // namespace fcitx

FCITX_ADDON_FACTORY_V2(notificationitem, fcitx::NotificationItemFactory)
