function [s32 c32 g32] = mp2scg(magDB, phase)

    mag = 10^(magDB/10);

    pRad = deg2rad(phase);

    c = mag*cos(pRad);
    s = mag*sin(pRad);
    
    % CORRECTOR 
    foo = fi(1, 1, 12, 11);
    corrector = 1-foo.data;
    
    g = 1/(max(1+s, c)) - corrector;
% g = 0.75;
    s32 = float_u32(s);
    c32 = float_u32(c);
    g32 = float_u32(g);

end