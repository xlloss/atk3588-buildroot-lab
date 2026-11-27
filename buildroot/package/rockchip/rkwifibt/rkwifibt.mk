################################################################################
#
# rkwifibt
#
################################################################################

RKWIFIBT_VERSION = 1.0.0
RKWIFIBT_SITE_METHOD = local
RKWIFIBT_SITE = $(TOPDIR)/../external/rkwifibt
RKWIFIBT_LICENSE = ROCKCHIP
RKWIFIBT_LICENSE_FILES = LICENSE

ifeq ($(BR2_PACKAGE_RKWIFIBT_STATIC),y)
RKWIFIBT_CFLAGS = $(TARGET_CFLAGS) -static
RKWIFIBT_LDFLAGS = $(TARGET_LDFLAGS) -static
endif

define RKWIFIBT_INSTALL_WIFIBT_FILES
	mkdir -p $(TARGET_DIR)/etc/init.d $(TARGET_DIR)/usr/bin \
		$(TARGET_DIR)/lib/modules $(TARGET_DIR)/lib/firmware/rtlbt \
		$(TARGET_DIR)/system/etc
	ln -rsf $(TARGET_DIR)/lib/firmware $(TARGET_DIR)/system/etc/firmware
	$(INSTALL) -m 0644 $(@D)/drivers/rtl8733bu/8733bu.ko $(TARGET_DIR)/lib/modules/
	$(INSTALL) -m 0644 $(@D)/drivers/bluetooth_usb_driver/rtk_btusb.ko $(TARGET_DIR)/lib/modules/
	$(INSTALL) -m 0644 $(@D)/firmware/realtek/RTL8733BU/* $(TARGET_DIR)/lib/firmware/
	$(INSTALL) -m 0644 $(@D)/firmware/realtek/RTL8733BU/* $(TARGET_DIR)/lib/firmware/rtlbt/
	$(INSTALL) -m 0644 $(@D)/conf/* $(TARGET_DIR)/etc/
	$(INSTALL) -m 0755 $(@D)/scripts/* $(TARGET_DIR)/usr/bin/
	for b in bt-tty wifibt-info wifibt-vendor wifibt-chip wifibt-module; do \
		ln -sf wifibt-util.sh $(TARGET_DIR)/usr/bin/$$b; \
	done
	$(INSTALL) -m 0755 $(@D)/S36wifibt-init.sh $(TARGET_DIR)/etc/init.d/S36wifibt-init.sh
endef
RKWIFIBT_POST_INSTALL_TARGET_HOOKS += RKWIFIBT_INSTALL_WIFIBT_FILES

$(eval $(meson-package))
