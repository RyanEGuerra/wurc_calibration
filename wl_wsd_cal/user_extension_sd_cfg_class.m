classdef user_extension_sd_cfg_class < wl_user_ext
    properties
       description; 
    end
    properties(Hidden = true,Constant = true)
       CMD_SD_INIT = 100;
       CMD_SD_DEBUG_PRINT = 101;
       CMD_SD_WRITE_BIN = 102;
       CMD_SD_CONFIG_GO = 110;
    end
    methods
        function obj = user_extension_sd_cfg_class()
            obj@wl_user_ext();
            obj.description = 'This is the sd_cfg user extension class.';
        end
        
         function out = procCmd(obj, nodeInd, node, varargin)
            %user_extension_example_class procCmd(obj, nodeInd, node, varargin)
            % obj: baseband object (when called using dot notation)
            % nodeInd: index of the current node, when wl_node is iterating over nodes
            % node: current node object (the owner of this baseband)
            % varargin:
            %  Two forms of arguments for commands:
            %   (...,'theCmdString', someArgs) - for commands that affect all buffers
            %   (..., RF_SEL, 'theCmdString', someArgs) - for commands that affect specific RF paths
            out = [];
            
            if(ischar(varargin{1}))
               %No RF paths specified
               cmdStr = varargin{1};    
               if(length(varargin)>1)
                   varargin = varargin(2:end);
               else
                   varargin = {};
               end
            else
               %RF paths specified
               rfSel = (varargin{1});
               cmdStr = varargin{2};

               if(length(varargin)>2)
                   varargin = varargin(3:end);
               else
                   varargin = {};
               end
            end
            
            cmdStr = lower(cmdStr);
            switch(cmdStr)
                case 'sd_init'
                    myCmd = wl_cmd(node.calcCmd(obj.GRP,obj.CMD_SD_INIT));
                    resp = node.sendCmd(myCmd);
                    ret = resp.getArgs();
                    if(ret ~= 0) fprintf('SD INIT Failed!\n'); end
                    
                case 'sd_debug_print'
                    myCmd = wl_cmd(node.calcCmd(obj.GRP,obj.CMD_SD_DEBUG_PRINT));
                    resp = node.sendCmd(myCmd);

                case 'sd_write_bitstream'
                    %Input args:
                    % 1: Slot to write (0:7)
                    % 2: .bin filename as string
                    slot = varargin{1};
                    if((slot < 0) || (slot > 7))
                        fprintf('Invalid Slot - punting\n');
                        return;
                    end

                    fd = fopen(varargin{2}, 'r');
                    if(fd < 0) fprintf('Unable to open file %s\n', varargin{1}); end
                    fbin = fread(fd, inf, 'uint32=>uint32', 0, 'b');
                    if(length(fbin) ~= 2308111) fprintf('Invalid .bin file (wrong size)\n'); end

                    %Pad bitstream to integral number of 512B blocks
                    fbin = [fbin; zeros(mod(-length(fbin), 128), 1)];

                    num_blocks = length(fbin) / 128;
                    blocks_per_pkt = floor(double(node.transport.getMaxPayload) / 512);
                    num_pkts = ceil(num_blocks / blocks_per_pkt);
                    
                    fprintf('Writing SD Image: 00%%');
                    for p = 0:num_pkts-1
                        myCmd = wl_cmd(node.calcCmd(obj.GRP,obj.CMD_SD_WRITE_BIN));
                        %args:
                        % 0: Byte offset into SD card to write
                        % 1: Blocks in this pkt
                        % 2: (512*blocks_in_pkt) bytes of data to write
                        
                        first_word_r = 1 + (p*blocks_per_pkt*128);
                        first_byte_w = (131072*512) + (slot*512*32768) + (4*(first_word_r-1));
                        myCmd.addArgs(first_byte_w);
                        if(p == num_pkts-1)
                            %Last packet - send trailing blocks
                            blks = fbin(first_word_r : end);
                            myCmd.addArgs(length(blks)/128);
                        else
                            last_byte_r  = first_word_r + blocks_per_pkt*128 - 1;
                            blks = fbin(first_word_r : last_byte_r);
                            myCmd.addArgs(blocks_per_pkt);
                        end
                        myCmd.addArgs(blks);
                        resp = node.sendCmd(myCmd);
                        ret = resp.getArgs();
                        fprintf('\b\b\b%02d%%', floor(100*p/num_pkts));
                        if(ret ~= 0) fprintf('SD write failed on pkt %d!\n', p); return; end
                    end
                    fprintf(' - Done\n\n');
                    
                    fclose(fd);
                    
                    
                case 'sd_reconfig'
                    myCmd = wl_cmd(node.calcCmd(obj.GRP,obj.CMD_SD_CONFIG_GO));
                    slot = varargin{1};
                    if((slot < 0) || (slot > 7))
                        fprintf('Invalid Slot - punting\n');
                        return;
                    end
                    myCmd.addArgs(slot);
                    resp = node.sendCmd(myCmd);
                    ret = resp.getArgs();
                    if(ret ~= 0) fprintf('SD Config Command Failed!\n'); end
            end
         end
        
    end
end
