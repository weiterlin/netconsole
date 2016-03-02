# netconsole
- 安装netconsole工具
<br>cp arping /system/bin/
<br>cp busybox /system/bin/
<br>cp netconsole.sh /system/bin/
- 在init.rc中添加netconsole服务
<br>service netconsole /system/bin/netconsole.sh
<br>    class main
<br>	user root
<br>	disabled
<br>on property:sys.netconcole=1
<br>	restart netconsole
<br>on property:sys.netconcole=0
<br>	stop netconsole
- 启动netconsole服务
<br>setprop sys.netconcole 0
<br>setprop sys.remote_port 6666
<br>setprop sys.remote_ip 172.16.6.111
<br>setprop sys.netconcole 1
- 使用SLogTools.exe工具,在Windows上抓取日志


