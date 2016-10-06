clear all;
n = wl_initNodes(4);
n(1:2) = [];

wl_setUserExtension(n,user_extension_sd_cfg_class);
wl_userExtCmd(n, 'sd_init');
%wl_userExtCmd(n, 'sd_debug_print');

bin_fn = 'C:\Users\rng\Dropbox\Shared_Naren_Ryan\sd_flashing_naren\download_wl_1000.bin';

%%
wl_userExtCmd(n, 'sd_write_bitstream', 0, bin_fn);

%%
wl_userExtCmd(n, 'sd_reconfig', 0);
