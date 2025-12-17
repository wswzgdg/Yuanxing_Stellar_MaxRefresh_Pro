#!/system/bin/sh

resetprop --delete persist.oplus.display.vrr
resetprop --delete persist.oplus.display.vrr.adfr
resetprop --delete debug.oplus.display.dynamic_fps_switch
resetprop --delete sys.display.vrr.vote.support
resetprop --delete vendor.display.enable_dpps_dynamic_fps
resetprop --delete ro.display.brightness.brightness.mode

settings delete system peak_refresh_rate
settings delete system min_refresh_rate
settings delete system user_refresh_rate
settings delete secure refresh_rate_mode
settings delete system oplus_customize_multi_mode_freq
