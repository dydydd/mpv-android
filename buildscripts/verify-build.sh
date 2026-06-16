#!/bin/bash
# MPV Android 构建验证脚本

echo "=========================================="
echo "MPV Android gpu-next 构建验证"
echo "=========================================="
echo

# 检查 libmpv.so 是否存在
LIBMPV="/home/li/code/LinPlayer/mpv-android/app/src/main/jniLibs/arm64-v8a/libmpv.so"
if [ -f "$LIBMPV" ]; then
    echo "✓ libmpv.so 存在"

    # 检查文件大小
    SIZE=$(du -h "$LIBMPV" | cut -f1)
    echo "  大小: $SIZE"

    # 检查 Vulkan 符号
    echo
    echo "检查 Vulkan 符号..."
    if readelf -s "$LIBMPV" | grep -q "vulkan\|pl_vulkan"; then
        echo "✓ 发现 Vulkan 相关符号"
        readelf -s "$LIBMPV" | grep -i vulkan | head -5
    else
        echo "✗ 未发现 Vulkan 符号"
    fi

    # 检查动态链接库
    echo
    echo "检查动态依赖..."
    readelf -d "$LIBMPV" | grep NEEDED

    # 检查是否链接了 libvulkan
    echo
    if readelf -d "$LIBMPV" | grep -q "libvulkan"; then
        echo "✓ 链接了 libvulkan.so"
    else
        echo "⚠ 未链接 libvulkan.so (这是正常的，Vulkan 在运行时加载)"
    fi

else
    echo "✗ libmpv.so 不存在"
    exit 1
fi

# 检查 shaderc 库
echo
echo "=========================================="
echo "检查 shaderc 编译结果"
echo "=========================================="
SHADERC_LIB="/home/li/code/LinPlayer/mpv-android/buildscripts/prefix/arm64/lib/libshaderc_combined.a"
if [ -f "$SHADERC_LIB" ]; then
    echo "✓ libshaderc_combined.a 存在"
    SIZE=$(du -h "$SHADERC_LIB" | cut -f1)
    echo "  大小: $SIZE"
else
    echo "✗ libshaderc_combined.a 不存在"
fi

# 检查 libplacebo
echo
echo "=========================================="
echo "检查 libplacebo 配置"
echo "=========================================="
PLACEBO_PC="/home/li/code/LinPlayer/mpv-android/buildscripts/prefix/arm64/lib/pkgconfig/libplacebo.pc"
if [ -f "$PLACEBO_PC" ]; then
    echo "✓ libplacebo.pc 存在"
    if grep -q "vulkan" "$PLACEBO_PC"; then
        echo "✓ libplacebo 配置了 Vulkan"
    else
        echo "✗ libplacebo 未配置 Vulkan"
    fi
else
    echo "✗ libplacebo.pc 不存在"
fi

echo
echo "=========================================="
echo "下一步操作"
echo "=========================================="
echo "1. 复制库文件到 Flutter 项目:"
echo "   cp $LIBMPV \\"
echo "      /home/li/code/LinPlayer/android/app/src/main/jniLibs/arm64-v8a/"
echo
echo "2. 重新构建 Flutter 应用:"
echo "   cd /home/li/code/LinPlayer"
echo "   flutter clean"
echo "   flutter build apk --debug"
echo
echo "3. 安装并测试:"
echo "   adb install -r build/app/outputs/flutter-apk/app-debug.apk"
echo "   adb logcat | grep -E 'gpu-next|vulkan|mpv'"
echo
