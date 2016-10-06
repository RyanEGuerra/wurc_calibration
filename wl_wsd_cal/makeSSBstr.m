function ret = makeSSBstr(mp)
% mp
    [s32 c32 g32] = mp2scg(mp(1), mp(2));
    
    ret = sprintf('0x%08X, 0x%08X, 0x%08X # MP={%1.2f, %1.2f}', ...
        s32, c32, g32, mp(1), mp(2));

end