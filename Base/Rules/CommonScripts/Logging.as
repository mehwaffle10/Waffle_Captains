shared void log(string func_name, string msg)
{
    string fullScriptName = getCurrentScriptName();
    string[]@ parts = fullScriptName.split("/");
    string shortScriptName = parts[parts.length-1];
    u32 t = getGameTime();

    printf("[Captains][" + shortScriptName + "][" + func_name + "][" + t + "] " + msg);
}

shared void logBroadcast(string func_name, string msg) {
    log(func_name, msg);
    getNet().server_SendMsg(msg);
}
