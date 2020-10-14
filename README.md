# daxun-chat
A chat(Message Gateway) framework based on openresty.

## 状态
* 目前还处于demo状态，欢迎有兴趣的同学一起完善。

## 描述
* 这是疫情期间，个人在家学习openresty时的试验品。主要是用来了解和学习openresty运作机制，踩了不少坑，也学习到了不少。之前查了一下openresty在这方面的尝试好像不太多（可能是我没有发现），希望daxun能给有此类需求的人提供些参考
* 目前仅实现了纯文本的聊天
* 功能的扩展性还是比较方便的，按需扩展，不仅用来做聊天，做个消息推送以及多人桌游什么的，也是可以的

## 架构设计
### 设计目标
* 高性能
* 可靠
* 可扩展
* 可定制
* 热更
### 分层
主要分3层：
* 业务层
  * 目前是并不完备的聊天业务
    * 聊天分群聊，私聊，等聊天的需要的功能
  * 可随时替换成成任何业务，例如：消息推送，多人游戏，等等
* 消息网关层
  * 核心层，负责管理连接状态和消息分发
* 网络层
  * 负责各种协议的封装处理，以及网络数据包的收发
### 模块
分两大模块：
* 核心模块
  * 在线管理模块
  * 消息分发模块
  * 网络协议模块
  * 网络通信模块
  * 数据库存储模块（待实现）
  * 静态资源管理模块（待实现）
  * 后台管理模块（待实现）
  * 缓存管理模块（待实现）
  * 异常管理模块（待实现）
  * 集群管理模块（待实现）
* 业务模块
  * 聊天模块 
  * 其它业务模块（待实现）
### 协议
* daxun网络协议
```
协议格式（二进制）：
HEADER(6bytes):
    length(4bytes,无符号):剩余长度
    version(1byte):协议的版本号
    flags(1byte):协议标志位（保留）
PAYLOAD:
    payload(允许为空)
包体总长度(4 + length)
```
* 聊天协议
```
协议格式（json）：
    _ver:[required] 1
    _type:[required] 网络消息类型；0:reserved; 1:ping; 2:pong; 3:auth; 4:private chat msg; 5:group chat msg; 6:instant msg
    _time:[required] long，时间戳，精确到毫秒，服务器收到的时间
    _id:[optional] reserved
    _from:[optional]
    _to:[optional]
    _offline:[optional] 是否存储离线消息；0:不存储；1:需要存储
    _chat_type:[optional] 聊天消息类型；0：文本；1：图片；2：音频；3：视频；4：链接
    _payload:[optional]
```
### 架构图
![daxun架构图](https://images.gitee.com/uploads/images/2020/1010/204448_262e7d6e_1741829.jpeg "daxun架构图")

## 测试使用
### 使用
* 首先得有一个*nix环境(Linux,Unix,Mac)都行
* 下载[openresty](http://openresty.org/)，按照官网文档进行安装
* daxun的test/www/目录下提供了一个聊天测试页面
* 参考daxun的test目录下的nginx.conf,配置好openresty
* 启动openresty你就可以测试使用了
* 然后改代码看看会发生什么
### 测试
* 通过test目录下的‘clitest.lua’测试脚本可以进行性能测试，具体怎么使用请参考‘clitest.lua’代码，需要先在文件头部配置一下‘package.path’，让测试脚本能用上daxun的代码
* 注意OS的ulimit要设置大一点

