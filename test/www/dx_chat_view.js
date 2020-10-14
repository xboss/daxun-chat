var DxChatView = {}
DxChatView.printMsg = function(msg) {
    var p = $('<p style="background:#EEEEEE;margin: 4px 4px 4px 4px;"></p>').text(msg);
    $("#msgView").append(p);
}