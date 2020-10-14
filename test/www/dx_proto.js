var DxProto = {}
DxProto.unpack = function(raw) {
    var msg = null;
    if (typeof raw === 'undefined' || raw == null || raw.byteLength < 6) {
        return;
    }
    
    var dataView = new DataView(raw);
    msg = {};
    msg.len = dataView.getInt32(0);
    msg.ver = dataView.getUint8(4);
    msg.flg = dataView.getUint8(5);
    var byteArray = [];
    for(var i = 6, len = raw.byteLength; i < len; i++){
        byteArray.push(dataView.getInt8(i));
    }
    var jsonStr = DxProto.byteArrayToString(byteArray);
    console.log(jsonStr)
    console.log(JSON.stringify(msg))
    msg.payload = JSON.parse(jsonStr);
    return msg;
}

DxProto.pack = function(chatMsg) {
    var raw = null;
    if (typeof chatMsg === 'undefined' || chatMsg == null) {
        return raw;
    }

    var dataArray = DxProto.stringToByteArray(JSON.stringify(chatMsg)); 
    raw = new ArrayBuffer(6 + dataArray.length);
    var dataView = new DataView(raw);
    dataView.setInt32(0, 2 + dataArray.length)
    dataView.setUint8(4, 0x01);
    dataView.setUint8(5, 0x00);
    for (var i = 0, len = dataArray.length; i < len; i++) {                                                           
        dataView.setUint8(6+i, dataArray[i]);                                                                        
    }
    return raw;
}

DxProto.stringToByteArray = function(str) {
    var code = encodeURIComponent(str);
    var bytes = [];
    for (var i = 0; i < code.length; i++) {
        var c = code.charAt(i);
        if (c === '%') {
            var hex = code.charAt(i + 1) + code.charAt(i + 2);
            var hexVal = parseInt(hex, 16);
            bytes.push(hexVal);
            i += 2;
        } else bytes.push(c.charCodeAt(0));
    }
    return bytes;
}

DxProto.byteArrayToString = function(bytes) {
    // var str = "";
    // for (var i = 0; i < bytes.length; i++) {
    //     str += '%' + bytes[i].toString(16);
    // }
    var str = String.fromCharCode.apply(String, bytes)
    console.log(str);
    return decodeURIComponent(str);
}
