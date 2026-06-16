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

mkdir -p _build$ndk_suffix
cd _build$ndk_suffix

cpu=armv7-a
[[ "$ndk_triple" == "aarch64"* ]] && cpu=armv8-a
[[ "$ndk_triple" == "x86_64"* ]] && cpu=generic
[[ "$ndk_triple" == "i686"* ]] && cpu="i686 --disable-asm"

cpuflags=
[[ "$ndk_triple" == "arm"* ]] && cpuflags="$cpuflags -mfpu=neon -mcpu=cortex-a8"

args=(
	--target-os=android --enable-cross-compile
	--cross-prefix=$ndk_triple- --cc=$CC --pkg-config=pkg-config --nm=llvm-nm
	--arch=${ndk_triple%%-*} --cpu=$cpu
	--extra-cflags="-I$prefix_dir/include $cpuflags" --extra-ldflags="-L$prefix_dir/lib"

	--enable-{jni,mediacodec,mbedtls,libdav1d,libxml2} --disable-vulkan
	--disable-static --enable-shared --enable-{gpl,version3}

	# disable unneeded parts
	--disable-{stripping,doc,programs}
	# to keep the build lean we disable some feature quite aggressively:
	# - muxers, encoders: mpv-android does not have any way to use these
	# - devices: no practical use on Android
	--disable-{muxers,encoders,devices}
	# useful to taking screenshots
	--enable-encoder=mjpeg,png
	# useful for the `dump-cache` command
	--enable-muxer=mov,matroska,mpegts

	# 启用音频解码器 - 解决 TrueHD 等音频无声问题
	--enable-decoder=truehd,aac,ac3,eac3,mp3,opus,vorbis,flac,dts,dtshd,pcm_*
	# 启用字幕解码器 - 解决 subrip/srt/ass 字幕不显示问题
	--enable-decoder=subrip,srt,ass,ssa,webvtt,mov_text,dvdsub,pgssub,hdmv_pgs_subtitle
	# 启用对应的解复用器
	--enable-demuxer=truehd,aac,ac3,eac3,mp3,ogg,wav,flac,dts,matroska,mov,srt,ass,subrip,webvtt,microdvd,mpl2,vplayer,sami
	# 启用对应的解析器
	--enable-parser=truehd,aac,ac3,eac3,mpegaudio,opus,vorbis,flac,dts

	# HDR/杜比视界支持 - 启用 10-bit 和 HDR 相关像素格式
	--enable-decoder=hevc,av1,vp9
	--enable-hwaccel=hevc_mediacodec,av1_mediacodec,vp9_mediacodec
	# 启用杜比视界解码器和解析器
	--enable-decoder=dolby_vision
	--enable-parser=dovi
)
../configure "${args[@]}"

make -j$cores
make DESTDIR="$prefix_dir" install
