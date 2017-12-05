

int main(int argc, char *argv[])
{
	@autoreleasepool
	{
		return NSApplicationMain(argc, (const char **)argv);
	}
}

/*
 基础
	OK> Bomb
	OK> Fuze
 
 设置
	!!> 关于：型号错误
	OK> 无线局域网
	??> 监管：需要更多机型图片
 
 联机
	OK> IMEI
	OK> ECID
	OK> 机型
	OK> 产品类型
	??> 颜色
	OK> 容量
 
 运行
	OK> *#06# IMEI
	OK> 信号模拟
	??> 诊断：待测
	??> 容量：待测
	??> 保留核心：待测
	??> CLICK：待测

 恢复：
	OK> 激活界面信息（i）
	OK> 手机激活
	??> 联机激活：偶尔弹出激活提示
	??> 删除通话记录
	??> 删除程序
	??> 最近通话
	??> 删除帐号：待测
	??> 删除个人收藏
 
 部署
	??> 封锁
	??> 解封
	??> 清理
	??> 反刷机
	??> 反越狱
	??> 状态文件
	??> 越狱检测：根本不要生成标记文件
	??> 抹掉特征
	??> 诊断助手

 插件（可选）
	NO> 跳过音量键：cyinject:	aborting...
	NO> 跳过日志：SubstrateLoader.dylib:	_asl_send	(32	&	64)
	NO> 随机路径：SubstrateLoader.dylib:	/Library/MobileSubstrate/DynamicLibraries	(32	&	64)

 优化
 chmod 是否必要
 诊断助手使用 OpenURL
 open 监控 xyj
 去掉 _ldBase

 */