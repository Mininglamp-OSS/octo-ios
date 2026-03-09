
xcode14.3 Archive 报错rsync error: some files could not be transferred (code 23)

解决方案一
安装Xcode 14.2
使用Xcode14.2打包或者在Xcode 14.3 Settings-Locations-Command Line Tools 选择 Xcode14.2

解决方案二
修改 /Pods/Target Support Files/Pods-{product名称}/Pods-{product名称}-frameworks.sh

replace
source="$(readlink "${source}")"
with
source="$(readlink -f "${source}")"

