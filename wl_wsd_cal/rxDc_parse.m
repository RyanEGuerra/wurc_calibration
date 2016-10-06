function ret = rxDc_parse(inp, dir)

if(strcmp(dir, 'toval'))

    msbTmp = bitand(inp, 64);
    
    if(msbTmp==64)
        sign=-1;
    else
        sign = 1;
    end
    
    mag = bitand(inp, 63);
    
    ret = mag*sign;
elseif(strcmp(dir, 'tocode'))
    if(inp>0)
        sign = 0;
    else
        sign = 64;
    end
    ret = bitor(abs(inp), sign);
    
    
end


end