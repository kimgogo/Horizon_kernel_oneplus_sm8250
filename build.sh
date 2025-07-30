#!/usr/bin/bash
set -e

DIR="$( cd "$( dirname "$0"  )" &&cd ..&& pwd  )"
source="$( cd "$( dirname "$0"  )" && pwd  )"

CLANG_PATH="${DIR}/clang"

args="-j$(nproc --all) \
O=out \
ARCH=arm64 \
CLANG_TRIPLE=aarch64-linux-gnu- \
CROSS_COMPILE=${CLANG_PATH}/bin/aarch64-linux-gnu- \
CC=${CLANG_PATH}/bin/clang \
CROSS_COMPILE_COMPAT=${CLANG_PATH}/bin/arm-linux-gnueabi- \
AR=${CLANG_PATH}/bin/llvm-ar \
NM=${CLANG_PATH}/bin/llvm-nm \
LLVM_AR=${CLANG_PATH}/bin/llvm-ar \
LLVM_NM=${CLANG_PATH}/bin/llvm-nm \
OBJCOPY=${CLANG_PATH}/bin/llvm-objcopy \
OBJDUMP=${CLANG_PATH}/bin/llvm-objdump \
STRIP=${CLANG_PATH}/bin/llvm-strip \
LD=${CLANG_PATH}/bin/ld.lld "

device="all"
clean="false"
action="build"
version="`date +"%m%d%H%M"`"
release="false"

print (){
case ${2} in
    "red")
    echo -e "\033[31m $1 \033[0m";;

    "blue")
    echo -e "\033[34m $1 \033[0m";;

    "yellow")
    echo -e "\033[33m $1 \033[0m";;

    "purple")
    echo -e "\033[35m $1 \033[0m";;

    "sky")
    echo -e "\033[36m $1 \033[0m";;

    "green")
    echo -e "\033[32m $1 \033[0m";;

    *)
    echo $1
    ;;
    esac
}

input=${*}

for i in ${input}
    do
        case ${i} in
            "op8")
            device="op8";;

            "op8p")
            device="op8p";;

            "op8t")
            device="op8t";;

            "all")
            device="all";;

            "--clean"|"-c"|"clean")
            clean="true";;
        *)
        did="false"

        if [[ $i =~ "-r=" ]];then
        release="true"&&version="${i#*r=}"&&did="true"
        fi

        if [[ $i =~ "-v=" ]];then
        version="${i#*v=}"&&did="true"
        fi
        
        if [ $did == "false" ]
        then
        print "Error input" red&&exit
        fi

        ;;
        esac
    done
    
mkzip (){
    if [ "${release}" == "true" ];then
    zipname="(${1})Horizon-Kernel-R${version}.zip"
    else
    zipname="(${1})Horizon-Kernel-${version}.zip"
    fi
    cp -f out/arch/arm64/boot/Image.gz ${DIR}/AnyKernel3
    #find ${source}/out/arch/arm64/boot/dts/vendor/qcom -name '*.dtb' -exec cat {} + > ${DIR}/AnyKernel3/dtb
    cp ${source}/out/arch/arm64/boot/dts/vendor/qcom/kona-v2.1.dtb ${DIR}/AnyKernel3/dtb
    #cp ${source}/out/arch/arm64/boot/dts/vendor/qcom/instantnoodle-t0.dtb ${DIR}/AnyKernel3/dtb
    cp ${source}/out/arch/arm64/boot/dtbo.img ${DIR}/AnyKernel3
    cd ${DIR}/AnyKernel3
    zip -r "${zipname}" *
    cp -f "${zipname}" ${DIR}
    rm -f "${zipname}"
    cd ${source}
    print "All done.Find it at ${DIR}/$zipname" green
}
    
build_op8(){
    print "Building Kernel for op8..." blue
    if [ -d "KernelSU" ]; then
        rm -rf KernelSU
    fi
    curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s susfs-1.5.7

    make $args instantnoodle_defconfig&&make $args
    mkzip "op8${1}"
}

build_op8p(){
    print "Building Kernel for op8p..." blue
    if [ -d "KernelSU" ]; then
        rm -rf KernelSU
    fi
    curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s susfs-1.5.7

    make $args instantnoodlep_defconfig&&make $args
    mkzip "op8p${1}"
}

build_op8t(){
    print "Building Kernel for op8t..." blue
    if [ -d "KernelSU" ]; then
        rm -rf KernelSU
    fi
    curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s susfs-1.5.7
    make $args kebab_defconfig&&make $args
    mkzip "op8t${1}"
}

bclean(){
    rm -rf ${source}/out/arch/arm64/boot
}

clean(){
    if [ "${clean}" == "true" ]
    then
        print "Doing cleanups" red
        make ${args} mrproper
    else
        bclean
    fi
}

if [ "${action}" == "build" ]
then
    if [ $release == "true" ]
    then
        print "You are building a release version:R${version}" green
        args+="LOCALVERSION=-R${version} "
    else
        print "You are building a snapshot version:${version}" yellow
        args+="LOCALVERSION=-${version} "
    fi
    
    if [ ${device} == "all" ]
    then
        git reset --hard
        
        clean
        build_op8t "-OOS"
        
        bclean
        git apply lineage.diff
        build_op8t "-Lineage"
        git reset --hard
        
        bclean
        build_op8p "-OOS"
        
        bclean
        git apply lineage.diff
        build_op8p "-Lineage"
        git reset --hard
        
        bclean
        git apply lineage.diff
        build_op8 "-Lineage"
        git reset --hard
        
        bclean
        build_op8 "-OOS"
        
    elif [ ${device} == "op8" ]
    then
        clean
        build_op8
    elif [ ${device} == "op8p" ]
    then
        clean
        build_op8p
    elif [ ${device} == "op8t" ]
    then
        clean
        build_op8t
    fi
fi