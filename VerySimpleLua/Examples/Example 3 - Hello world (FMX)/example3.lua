
function GetCommands(iLine, iColumn)
 local switches =
        {{'Switch1','Luz 1','http://192.168.15.200:8081/zeroconf/switch','SwitchR3'},
         {'Switch2','Ventilador','http://192.168.15.203:8081/zeroconf/switch','10011c68d'},
         {'Switch3','Aquecedor','','SwitchMini3'}}
 return switches[iLine][iColumn]
end

function LuaInitCommands(index)
  return GetCommands(index,3), GetCommands(index,2), GetCommands(index,1)
end

function LuaActionInfo(temp)
  if temp>30 then 
    return "Switch2", "", ""
  elseif temp<20 then   
    return "Switch2", "Switch3", ""
  else
    return "", "", ""   
  end
end

