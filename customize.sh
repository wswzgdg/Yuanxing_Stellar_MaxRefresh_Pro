#!/system/bin/sh
SKIPUNZIP=1

if  [ "$KSU" = "true" ]; then
    ROOT_IMPL="KernelSU"
    ROOT_VER="$KSU_VER"
else
    ROOT_IMPL="Magisk"
    ROOT_VER="$MAGISK_VER"
fi

unzip -o "$ZIPFILE" -d "$MODPATH" >&2

set_perm_recursive $MODPATH 0 0 0755 0644
set_perm $MODPATH/service.sh 0 0 0755
set_perm $MODPATH/post-fs-data.sh 0 0 0755
set_perm $MODPATH/uninstall.sh 0 0 0755
set_perm_recursive $MODPATH/webroot 0 0 0755 0644

MODID="Yuanxing_Stellar_MaxRefresh_Pro"
OLD_MODDIR="/data/adb/modules/$MODID"
PERSISTENT_DIR="/data/adb/${MODID}_data"

mkdir -p "$PERSISTENT_DIR"
set_perm "$PERSISTENT_DIR" 0 0 0755

if [ -f "$PERSISTENT_DIR/saved_config" ]; then
    cp -af "$PERSISTENT_DIR/saved_config" "$MODPATH/saved_config"
elif [ -f "$OLD_MODDIR/saved_config" ]; then
    cp -af "$OLD_MODDIR/saved_config" "$MODPATH/saved_config"
    cp -af "$OLD_MODDIR/saved_config" "$PERSISTENT_DIR/saved_config"
else
    touch "$MODPATH/saved_config"
fi

if [ -f "$PERSISTENT_DIR/apps.conf" ]; then
    cp -af "$PERSISTENT_DIR/apps.conf" "$MODPATH/apps.conf"
elif [ -f "$OLD_MODDIR/apps.conf" ]; then
    cp -af "$OLD_MODDIR/apps.conf" "$MODPATH/apps.conf"
    cp -af "$OLD_MODDIR/apps.conf" "$PERSISTENT_DIR/apps.conf"
else
    touch "$MODPATH/apps.conf"
fi

set_perm "$MODPATH/saved_config" 0 0 0644
set_perm "$MODPATH/apps.conf" 0 0 0644

GETPROP="/system/bin/getprop"
DEVICE_MODEL=$("$GETPROP" ro.product.model)
[ -z "$DEVICE_MODEL" ] && DEVICE_MODEL=$("$GETPROP" ro.product.odm.model)

MARKET_NAME=$("$GETPROP" ro.vendor.oplus.market.name)
[ -z "$MARKET_NAME" ] && MARKET_NAME=$("$GETPROP" ro.product.market.name)
[ -z "$MARKET_NAME" ] && MARKET_NAME="$DEVICE_MODEL"

BRAND=$("$GETPROP" ro.product.brand)
[ -z "$BRAND" ] && BRAND=$("$GETPROP" ro.product.system.brand)
BRAND=$(echo "$BRAND" | tr '[:upper:]' '[:lower:]')

MANUFACTURER=$("$GETPROP" ro.product.manufacturer)
[ -z "$MANUFACTURER" ] && MANUFACTURER=$("$GETPROP" ro.product.system.manufacturer)
MANUFACTURER=$(echo "$MANUFACTURER" | tr '[:upper:]' '[:lower:]')

echo "============================================="
echo "- 正在监测设备品牌…"

BRAND_OK=0
if echo "$BRAND" | grep -qiE "oneplus|oppo|realme|oplus"; then
    BRAND_OK=1
elif echo "$MANUFACTURER" | grep -qiE "oneplus|oppo|realme|oplus"; then
    BRAND_OK=1
elif echo "$DEVICE_MODEL" | grep -qiE "^PHK|^PH[A-Z]|^CPH|^RMX|^PJ[A-Z]"; then
    BRAND_OK=1
fi

if [ "$BRAND_OK" -eq 0 ]; then
    echo "❌ 设备品牌监测失败!"
    echo "---------------------------------------------"
    echo "监测到的品牌: $BRAND"
    echo "监测到的制造商: $MANUFACTURER"
    echo "监测到的型号: $DEVICE_MODEL"
    echo "---------------------------------------------"
    echo "此模块仅支持: OnePlus / OPPO / Realme"
    echo "安装已取消!"
    echo "============================================="
    exit 1
fi

echo "✓ 品牌监测通过: $BRAND / $MANUFACTURER"
echo "============================================="
echo "- 正在激活并监测刷新率档位…"

for i in 0 1 2 3 4 5 6 7 8 9 10; do
    service call SurfaceFlinger 1035 i32 $i >/dev/null 2>&1
    usleep 100000
done

sleep 1

LIST_FRAMEWORK=$(dumpsys display | grep -oE "fps=[0-9.]+" | awk -F= '{print $2}')
LIST_SF=$(dumpsys SurfaceFlinger | grep -oE "fps[=:][0-9.]+" | awk -F'[=:]' '{print $2}')
ALL_RATES="$LIST_FRAMEWORK $LIST_SF"
DETECTED=$(echo "$ALL_RATES" | tr ' ' '\n' | awk '{if($1>=30) printf("%.0f\n", $1)}' | sort -n | uniq)

if [ -z "$DETECTED" ]; then
    echo "[-] 未监测到有效档位,使用默认值"
    DETECTED="60 90 120"
fi

RATES=$(echo "$DETECTED" | xargs)

MAX_ID=$(dumpsys display 2>/dev/null | grep -oE "\{id=[0-9]+, width=[0-9]+, height=[0-9]+, fps=[0-9.]+" | awk -F'[,=]' '{print $2}' | sort -n | tail -n1)

if [ -z "$MAX_ID" ]; then
    MAX_ID=1
fi

RESTORE_ID=$((MAX_ID - 1))
service call SurfaceFlinger 1035 i32 $RESTORE_ID >/dev/null 2>&1

ANDROID_VER=$("$GETPROP" ro.build.version.release)
ROM_VERSION=$("$GETPROP" ro.build.display.id)
FINGERPRINT=$("$GETPROP" ro.build.fingerprint)
KERNEL_VER=$(uname -r)

if [ -f /sys/class/power_supply/battery/capacity ]; then
    BAT_LEVEL=$(cat /sys/class/power_supply/battery/capacity)%
else
    BAT_LEVEL="未知"
fi

if [ -f /sys/class/power_supply/battery/temp ]; then
    RAW_TEMP=$(cat /sys/class/power_supply/battery/temp)
    if [ -n "$RAW_TEMP" ]; then
        BAT_TEMP=$((RAW_TEMP / 10))
        BAT_TEMP="${BAT_TEMP}°C"
    else
        BAT_TEMP="未知"
    fi
else
    BAT_TEMP="未知"
fi

echo "---------------------------------------------"
echo "【设备信息监测】"
echo "1. 机型型号: $DEVICE_MODEL"
echo "2. 机型名称: $MARKET_NAME"
echo "3. 安卓版本: Android $ANDROID_VER"
echo "4. 内核版本: $KERNEL_VER"
echo "5. 系统版本: $ROM_VERSION"
echo "6. 系统指纹: $FINGERPRINT"
echo "---------------------------------------------"
echo "【状态监测】"
echo "7. 当前电量: $BAT_LEVEL"
echo "8. 电池温度: $BAT_TEMP"
echo "9. 支持刷新率: $RATES"
echo "10. Root方案: $ROOT_IMPL $ROOT_VER"
echo "---------------------------------------------"

key_check() {
    while true; do
        INPUT=$(timeout 0.1 getevent -l 2>/dev/null | grep -E "KEY_VOLUME|0072|0073")
        if echo "$INPUT" | grep -qE "KEY_VOLUMEUP|0073"; then
            if echo "$INPUT" | grep -q "DOWN"; then echo "KEY_VOLUMEUP"; return; fi
        elif echo "$INPUT" | grep -qE "KEY_VOLUMEDOWN|0072"; then
            if echo "$INPUT" | grep -q "DOWN"; then echo "KEY_VOLUMEDOWN"; return; fi
        fi
    done
}

echo "============================================="
echo "- 是否禁用LTPO？"
echo " "
echo "  [ 音量键上 (+) ] : 禁用LTPO (完整功能)"
echo "  [ 音量键下 (-) ] : 保留LTPO (仅应用刷新率切换)"
echo "============================================="

DISABLE_LTPO="true"
key=$(key_check)

if [ "$key" = "KEY_VOLUMEUP" ]; then
    DISABLE_LTPO="true"
    echo "- 已选择：禁用LTPO"
    LTPO_STATUS="已禁用"
else
    DISABLE_LTPO="false"
    echo "- 已选择：保留LTPO (仅应用刷新率切换)"
    LTPO_STATUS="已保留"
    echo "#!/system/bin/sh" > "$MODPATH/post-fs-data.sh"
fi

cat > "$MODPATH/module.prop" <<PROP
id=Yuanxing_Stellar_MaxRefresh_Pro
name=星驰引擎_极速高刷Pro
version=v3.0
versionCode=30
author=酷安@穆远星
description=为${MARKET_NAME}(${DEVICE_MODEL})提供极速高刷。LTPO状态: ${LTPO_STATUS}。监测到刷新率: ${RATES}。首次刷入请配置。后续重启将自动切换至选定的全局刷新率档位。应用配置页面，填写目标应用包名及刷新率档位对应ID，即可为指定应用单独配置专属刷新率，实时生效。
updateJson=https://raw.githubusercontent.com/MuYuanXing/Yuanxing_Stellar_MaxRefresh_Pro/main/update.json
PROP

echo "============================================="
echo "- 监测完成，环境安全。"
echo "- 可以关注下我的酷安吗喵？🥹🥹🥹"
echo "  (作者: 穆远星 / ID: 28719807)"
echo " "
echo "  [ 音量键上 (+) ] : 好的喵 (关注并安装) 🥰"
echo "  [ 音量键下 (-) ] : 不要喵 (直接安装) 😤"
echo "============================================="

JUMP_HOME="false"
key=$(key_check)

if [ "$key" = "KEY_VOLUMEUP" ]; then
    JUMP_HOME="true"
    echo "- 已选择：关注远星喵🥰🥰🥰"
else
    echo "- 已选择：不关注远星😤😤😤"
fi

echo "============================================="
echo "✅ 安装完成！重启后生效"
echo "============================================="

BOOT_COMPLETED=$("$GETPROP" sys.boot_completed)
if [ "$JUMP_HOME" = "true" ] && [ "$BOOT_COMPLETED" = "1" ]; then
    sleep 1
    echo "- 正在唤起酷安..."
    am start -a android.intent.action.VIEW -d "http://www.coolapk.com/u/28719807" >/dev/null 2>&1
fi

exit 0
