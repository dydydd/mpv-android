#!/bin/bash -e

. ../../include/path.sh

if [ "$1" == "build" ]; then
	true
elif [ "$1" == "clean" ]; then
	rm -rf _build$ndk_suffix
	exit 0
else
	exit 255
fi

build=_build$ndk_suffix

# shaderc 源码在 NDK 中
ndk_dir="$PWD/../../sdk/android-ndk-r29"
shaderc_src="$ndk_dir/sources/third_party/shaderc"

if [ ! -d "$shaderc_src" ]; then
	echo "ERROR: shaderc source not found at $shaderc_src"
	exit 1
fi

# 根据架构设置 APP_ABI
case "$ndk_triple" in
	arm-linux-androideabi)
		app_abi="armeabi-v7a"
		;;
	aarch64-linux-android)
		app_abi="arm64-v8a"
		;;
	i686-linux-android)
		app_abi="x86"
		;;
	x86_64-linux-android)
		app_abi="x86_64"
		;;
	*)
		echo "ERROR: Unknown architecture $ndk_triple"
		exit 1
		;;
esac

# 创建临时 Application.mk
mkdir -p $build
cat > $build/Application.mk <<EOF
APP_ABI := $app_abi
APP_PLATFORM := android-21
APP_STL := c++_shared
APP_OPTIM := release
EOF

# 使用 ndk-build 编译 shaderc
cd $build
"$ndk_dir/ndk-build" \
	NDK_PROJECT_PATH=. \
	NDK_APPLICATION_MK=Application.mk \
	APP_BUILD_SCRIPT="$shaderc_src/Android.mk" \
	-j$cores

# 查找编译好的库
echo "Looking for compiled libraries..."
find . -name "*.a" -o -name "*.so" | grep shaderc

# 合并所有 shaderc 相关库到一个 combined 库
if [ -f "obj/local/$app_abi/libshaderc.a" ]; then
	mkdir -p "$prefix_dir/lib"

	# 创建临时目录来提取所有 .o 文件
	temp_dir=$(mktemp -d)
	echo "Using temp directory: $temp_dir"

	# 提取所有相关库的 .o 文件，为每个库创建独立的子目录避免文件名冲突
	for lib in libshaderc.a libshaderc_util.a libSPIRV-Tools.a libSPIRV-Tools-opt.a libSPIRV.a libglslang.a libHLSL.a libOGLCompiler.a libOSDependent.a; do
		libpath="obj/local/$app_abi/$lib"
		if [ -f "$libpath" ]; then
			echo "Extracting $lib..."
			# 为每个库创建子目录
			libdir="$temp_dir/${lib%.a}"
			mkdir -p "$libdir"
			(cd "$libdir" && ar x "$OLDPWD/$libpath")
		fi
	done

	# 合并所有 .o 文件到新的库（使用find找到所有.o文件）
	echo "Combining all object files..."
	(cd "$temp_dir" && find . -name "*.o" -exec ar rcs "$prefix_dir/lib/libshaderc_combined.a" {} +)

	# 清理
	rm -rf "$temp_dir"

	echo "Created combined libshaderc_combined.a ($(ls -lh $prefix_dir/lib/libshaderc_combined.a | awk '{print $5}'))"
else
	echo "ERROR: libshaderc.a not found after build"
	echo "Searching in obj directory:"
	find obj -name "*.a" | head -20
	exit 1
fi

# 复制头文件
mkdir -p "$prefix_dir/include/shaderc"
cp -r "$shaderc_src/libshaderc/include/shaderc"/* "$prefix_dir/include/shaderc/" 2>/dev/null || true
cp "$shaderc_src"/libshaderc/include/*.h "$prefix_dir/include/shaderc/" 2>/dev/null || true

# 创建 pkg-config 文件
mkdir -p "$prefix_dir/lib/pkgconfig"
cat > "$prefix_dir/lib/pkgconfig/shaderc.pc" <<EOF
prefix=$prefix_dir
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: shaderc
Description: Shaderc shader compiler
Version: 2024.0
Libs: -L\${libdir} -lshaderc_combined
Cflags: -I\${includedir}
EOF

echo "shaderc build completed successfully"
