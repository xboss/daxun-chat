var DxWs = {};
DxWs.ws = null;
DxWs.log = null;
DxWs.pingLoop = null;
DxWs.init = function(logger) {
    DxWs.log = logger;
}
DxWs.connect = function(uri) {
    if (DxWs.ws != null && DxWs.ws.readyState == 1) {
        DxWs.log("已经在线");
        return;
    }

    if (!("WebSocket" in window)) {
        // The browser doesn't support WebSocket
        alert("WebSocket NOT supported by your Browser!");
        return;
    }

    // "ws://"+window.location.host+"/ws"
    DxWs.ws = new WebSocket(uri);
    DxWs.ws.binaryType = "arraybuffer";

    DxWs.ws.onopen = function () {
        DxWs.log("start...");
        // auth
        var chatMsg = {
            _ver : 1,
            _type : 3,
            _time: Date.now(),
            _payload : {
                ticket : $('#uidText').val()
            }
        };
        DxWs.ws.send(DxProto.pack(chatMsg))
    
        DxWs.log("setInterval...")
        DxWs.pingLoop = window.setInterval(function () { //每隔5秒钟发送一次心跳，避免websocket连接因超时而自动断开
            var ping = {}
            ping._ver = 1;
            ping._type = 1;
            ping._time = Date.now();
            // DxWs.log("ping " + JSON.stringify(ping))
            DxWs.ws.send(DxProto.pack(ping));
        }, 1000);
    };
    
    DxWs.ws.onmessage = function (event) {
        // console.log(event.data);
        var chatMsg = DxProto.unpack(event.data).payload;
        // console.log(JSON.stringify(chatMsg));
        if (chatMsg._type != 2) {
            
            if (chatMsg._type == 3) {
                // auth消息
                if (chatMsg._payload.cd == 0) {
                    DxWs.log('auth ok' + JSON.stringify(chatMsg));
                }
            } else if (chatMsg._type == 4) {
                DxWs.log(JSON.stringify(chatMsg));
            }
        }
    
    };
    
    DxWs.ws.onclose = function () {
        // websocket is closed.
        DxWs.log("已经和服务器断开");
        if (DxWs.pingLoop != null) {
            clearInterval(DxWs.pingLoop);
        }
    };
    
    DxWs.ws.onerror = function (event) {
        console.log("error " + event.data);
        DxWs.log("error " + event.data)
    };
}

DxWs.close = function() {
    if (DxWs.ws != null && DxWs.ws.readyState == 1) {
        DxWs.ws.close();
    }
}
