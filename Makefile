include theos/makefiles/common.mk

TWEAK_NAME = ArrageStatusBar
ArrageStatusBar_FILES = Tweak.xm
ArrageStatusBar_FRAMEWORKS = UIKit CoreGraphics
include $(THEOS_MAKE_PATH)/tweak.mk
