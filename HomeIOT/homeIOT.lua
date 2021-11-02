
function GetCommands(iLine, iColumn)
 -- IMPORTANT! DO NOT REMOVE THE LAST LINE {"","","",""}
 local switches =
        {{"Switch1","Luz 1","http://192.168.15.200:8081/zeroconf/switch","SwitchR3"},
         {"Switch2","Ventilador","http://192.168.15.203:8081/zeroconf/switch","10011c68d"},
         {"Switch3","Aquecedor","","SwitchMini3"},
		 {"","","",""}}
 return switches[iLine][iColumn]  
end

function GetSensors(iLine, iColumn)
 local sensors =
        {{"Camera","http://192.168.15.205/jpg","Cam"},
         {"Termometro","http://192.168.15.205/temp","Temp"},
         {"","",""}}
 return sensors[iLine][iColumn]  
end

function InitCommands(index)
  return GetCommands(index,4), GetCommands(index,3), GetCommands(index,2), GetCommands(index,1)
end

function InitSensors(index)
  return GetSensors(index,3), GetSensors(index,2), GetSensors(index,1)
end

function ActionInfo(temp)
  if temp>30 then 
    return "Switch2", "", ""
  elseif temp<20 then   
    return "Switch1", "Switch3", ""
  else
    return "", "", ""   
  end
end

