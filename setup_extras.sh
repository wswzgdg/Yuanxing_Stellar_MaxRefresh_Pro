#!/system/bin/sh
wait_key() {
    getevent -qt 1 >/dev/null 2>&1
    while true; do
        event=$(getevent -lqc 1 2>/dev/null | {
            while read -r line; do
                case "$line" in
                    *KEY_VOLUMEDOWN*DOWN*) echo "down" && break ;;
                    *KEY_VOLUMEUP*DOWN*) echo "up" && break ;;
                    *KEY_POWER*DOWN*)
                        input keyevent KEY_POWER
                        echo "power" && break ;;
                esac
            done
        })
        [ -n "$event" ] && echo "$event" && return
        usleep 30000
    done
}

echo "============================================="
echo "星驰引擎 - 正在安装"
echo "============================================="

GETPROP="/system/bin/getprop"
DEVICE_MODEL=$("$GETPROP" ro.product.model)
[ -z "$DEVICE_MODEL" ] && DEVICE_MODEL=$("$GETPROP" ro.product.odm.model)

MARKET_NAME=$("$GETPROP" ro.vendor.oplus.market.name)
[ -z "$MARKET_NAME" ] && MARKET_NAME=$("$GETPROP" ro.product.market.name)
[ -z "$MARKET_NAME" ] && MARKET_NAME="$DEVICE_MODEL"

echo "- 正在检测刷新率档位..."
for i in 0 1 2 3 4 5 6 7 8 9 10; do
    service call SurfaceFlinger 1035 i32 $i >/dev/null 2>&1
    usleep 100000
done

LIST_FRAMEWORK=$(dumpsys display | grep -oE "fps=[0-9.]+" | awk -F= '{print $2}')
LIST_SF=$(dumpsys SurfaceFlinger | grep -oE "fps[=:][0-9.]+" | awk -F'[=:]' '{print $2}')
ALL_RATES="$LIST_FRAMEWORK $LIST_SF"
DETECTED=$(echo "$ALL_RATES" | tr ' ' '\n' | awk '{if($1>=30) printf("%.0f\n", $1)}' | sort -n | uniq)

if [ -z "$DETECTED" ]; then
    echo "[-] 未检测到有效档位，使用默认值"
    sleep 1
    DETECTED="60 90 120"
fi

RATES=$(echo "$DETECTED" | xargs)

MAX_ID=$(dumpsys display 2>/dev/null | grep -oE "\{id=[0-9]+, width=[0-9]+, height=[0-9]+, fps=[0-9.]+" | awk -F'[,=]' '{print $2}' | sort -n | tail -n1)

if [ -z "$MAX_ID" ]; then
    MAX_ID=1
fi

RESTORE_ID=$((MAX_ID - 1))
service call SurfaceFlinger 1035 i32 $RESTORE_ID >/dev/null 2>&1

echo "============================================="
echo "- 是否禁用LTPO？"
echo " "
echo "  [ 音量键上 (+) ] : 禁用LTPO (完整功能)"
echo "  [ 音量键下 (-) ] : 保留LTPO (仅应用刷新率切换)"
echo " "
echo "============================================="

DISABLE_LTPO="true"
LTPO_STATUS="已禁用"
key=$(wait_key)

if [ "$key" = "down" ]; then
    DISABLE_LTPO="false"
    LTPO_STATUS="已保留"
    if [ -f "$MODPATH/post-fs-data.sh" ]; then
        echo "#!/system/bin/sh" > "$MODPATH/post-fs-data.sh"
        set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
    fi
    echo "- 已选择：保留LTPO"
else
    echo "- 已选择：禁用LTPO"
fi

sleep 1

echo "============================================="
echo "- 监测完成，环境安全。"
echo "- 可以关注下我的酷安吗喵？🥹🥹🥹"
echo "  (作者: 穆远星 / ID: 28719807)"
echo " "
echo "  [ 音量键上 (+) ] : 好的喵 (关注并安装) 🥰"
echo "  [ 音量键下 (-) ] : 不要喵 (直接安装) 😤"
echo "============================================="

JUMP_HOME="false"
key=$(wait_key)

if [ "$key" = "up" ]; then
    JUMP_HOME="true"
    echo "- 感谢支持！"
else
    echo "- 跳过关注"
fi

MODULE_PROP_PATH="$MODPATH/module.prop"
if [ -z "$MODPATH" ]; then
    MODULE_PROP_PATH="/data/adb/modules_update/Yuanxing_Stellar_MaxRefresh_Pro/module.prop"
fi

DESCRIPTION="为${MARKET_NAME}(${DEVICE_MODEL})提供极速高刷。LTPO状态: ${LTPO_STATUS}。监测到刷新率: ${RATES}。首次刷入请配置。后续重启将自动切换至选定的全局刷新率档位。应用配置页面，填写目标应用包名及刷新率档位对应ID，即可为指定应用单独配置专属刷新率，实时生效。"

DESCRIPTION_ESCAPED=$(echo "$DESCRIPTION" | sed 's/[\/&]/\\&/g')

if grep -q "^description=" "$MODULE_PROP_PATH"; then
    sed -i "s/^description=.*/description=${DESCRIPTION_ESCAPED}/" "$MODULE_PROP_PATH"
else
    echo "description=${DESCRIPTION}" >> "$MODULE_PROP_PATH"
fi

sleep 1

echo "- 已更新模块属性文件"

if [ "$JUMP_HOME" = "true" ]; then
    BOOT_COMPLETED=$("$GETPROP" sys.boot_completed)
    if [ "$BOOT_COMPLETED" = "1" ]; then
        sleep 1
        echo "- 正在打开酷安..."
        am start -a android.intent.action.VIEW -d "http://www.coolapk.com/u/28719807" >/dev/null 2>&1
    fi
fi

echo "============================================="
echo "✅ 配置已完成！"
echo "============================================="

exit 0