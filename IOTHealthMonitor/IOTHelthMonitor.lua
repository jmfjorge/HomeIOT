function ActionInfo(iBPM, iSPO2, iTime)
  if (iBPM>120 or iSPO2<95)  and (iTime>30) then 
    return true
  else
    return false
  end
end
