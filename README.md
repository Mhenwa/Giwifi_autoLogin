# 介绍

这是一个能够自动登录GiWifi校园网的shell脚本，在原作者的基础上：

1. 适配山东科技大学GIWIFI的接口、加密方式
2. 增加适用于OpenWrt的开机自动运行配置

**原作者**: [TwiceTry](https://github.com/TwiceTry)

# 使用

##  配置


路由器上面需要安装`wget-ssl`,`bash`(路由器自带的均为精简版,指令不全,会出现问题)和`openssl-util`

```
opkg update
opkg install bash
opkg install wget-ssl
opkg install openssl-util
```

## 运行

```bash
./giwifi.sh <username> <password> [baseUrl]
```
示例
```bash
chmod +x giwifi_new.sh
./giwifi_new.sh 12345678901 123456 http://10.100.100.2
```

## 开机运行
0. 将[giwifi.sh](./giwifi.sh)放到`/mnt`下，推荐的目录结构如下：

```
/mnt/giwifi/
 ├─ giwifi_new.sh
 └─ giwifi_log.txt
```

1. 修改[giwifi](./giwifi)中的账号、密码

2. 移动至`/etc/init.d/giwifi`

3. 赋予权限`chmod +x /etc/init.d/giwifi`

4. 加入开机自启动`/etc/init.d/giwifi enable`

5. 直接运行测试`/etc/init.d/giwifi start`或重启设备测试`reboot`


# 其它

## 脚本执行流程

![image](https://mermaid.ink/svg/pako:eNptkcFKw0AURX-lvHX7A1m4UtzUTbvTcTE002QgmanpBJG2UMWVRStoBTVWiosWcSGCVqzSn3GS-Be-dFJ14e5x597zLvNaUJM2AwvqntytuTRQhXKFiEKhqnDeIqDfu3rcI7CdiaXSSptAengVRw-6fxAPHtOTqe5fEGhX2E7ImlnCSMnlTH8MvkbPrvK9PJ57csr4Lh6e1gPfkw4X6WiijwfIWWcKVyv2A9LRJHmbJ0cvcXc_5yw9BqSnT8aD6bJ0ZJiV-HztLZSF36joLmer8NWU-33lwqCMnszO4mGUzs_19RCZa8LOIije3P5bII7u_xbggggogs8Cn3Ibv7aVRQgol_mMgIWjxx1XESCig0YaKlndEzWwVBCyIoQNG9GrnDoB9cGqU6-JKrO5ksGGOdbiZkVoULEp5dLT-QbYfsmr "脚本执行流程")

## Giwifi加密方式

```
明文字符串
-> 转成字节
-> 按 16 字节补 0
-> AES-128-CBC
-> Base64
```

## 多端设备

根据登录接口来说，可以在登录时伪装giwifi终端类型，此脚本是伪装成PC登录。

实测使用浏览器的开发者选项可以伪装成ipad，但不能伪装成apad

**Giwifi：是高贵的苹果人，放行！**