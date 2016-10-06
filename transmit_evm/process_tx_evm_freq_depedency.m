%

clear all;
close all;
% figure(1);
% clf(1);
% figure(2);
% clf(2);
NUM_NEW_PLOTS = 6;

exp_strings = {...
    'tx_evm_27-May-2015_0005A_00059_68736.mat',...
    'tx_evm_27-May-2015_00059_0005A_56326.mat',...
    ...
    'tx_evm_26-May-2015_00057_00058_99326.mat',...
    'tx_evm_26-May-2015_00058_00057_90579.mat',...
    ...
    'tx_evm_22-May-2015_00060_00061_99326.mat',...
    'tx_evm_22-May-2015_00061_00060_90579.mat',...
    ...
    ...%'mat_files/tx_evm_01-Dec-2014_00055_00056_54688.mat',...
    'mat_files/tx_evm_01-Dec-2014_00056_00055_62913.mat',...
    'mat_files/tx_evm_02-Dec-2014_00051_00053_77025.mat',...
    'mat_files/tx_evm_02-Dec-2014_00053_00051_643.mat',...
    'mat_files/tx_evm_03-Dec-2014_00052_00054_98208.mat',...
    'mat_files/tx_evm_03-Dec-2014_00054_00052_69174.mat',...
    'mat_files/tx_evm_09-Aug-2014_0004D_0004E_60700.mat',...
    'mat_files/tx_evm_10-Aug-2014_0004E_0004D_94879.mat',...
    'mat_files/tx_evm_09-Aug-2014_0004F_00050_81363.mat',...
    'mat_files/tx_evm_09-Aug-2014_00050_0004F_6997.mat',...
    'mat_files/tx_evm_08-Aug-2014_0004B_0004C_64457.mat',...
    'mat_files/tx_evm_08-Aug-2014_0004C_0004B_50369.mat',...
    'mat_files/tx_evm_07-Aug-2014_0004A_00048_71936.mat',...
    'mat_files/tx_evm_07-Aug-2014_00048_0004A_95717.mat'...
    'mat_files/tx_evm_23-Jun-2014_00046_00047_63320.mat',...
    'mat_files/tx_evm_23-Jun-2014_00047_00046_99326.mat',...
    'mat_files/tx_evm_21-Jun-2014_00045_00044_85509.mat',...
    'mat_files/tx_evm_23-Jun-2014_00044_00045_74916.mat',...
    'mat_files/tx_evm_21-Jun-2014_00042_00043_67471.mat',...
    'mat_files/tx_evm_21-Jun-2014_00043_00042_80125.mat',...
    'mat_files/tx_evm_20-Jun-2014_0003F_00040_89092.mat',...
    'mat_files/tx_evm_20-Jun-2014_00040_0003F_290.mat',...
    'mat_files/tx_evm_june16_0003C_00025_86905.mat',...
    'mat_files/tx_evm_june16_00039_0003D_55383.mat',...
    'mat_files/tx_evm_june15_0003D_00039_55645.mat',...
    'mat_files/tx_evm_june12_0002E_00038_10293.mat',...
    'mat_files/tx_evm_june12_0003A_0003E_18599.mat',...
    'mat_files/tx_evm_june12_0003E_0003A_71194.mat',...
    'mat_files/tx_evm_june12_00038_0002E_58570.mat',...
    };
NUM_TO_PLOT = 10% length(exp_strings);
plot_strs = {'d-r', 'd-g', '.-c', '.-c', '.-c', '.-c', '.-b', '.-b', '.-b'};
legend_str = {};
% first trials
% FREQ_VEC = [472:6:598]*1000;    % kHz
% TX_GAIN_VEC = 25:1:50;          % dB
% NUM_TRIALS = 50;
% ATTENUATION = 70;

% second trials, with better range
FREQ_VEC = [472:6:698]*1000;    % kHz
TX_GAIN_VEC = 15:1:50;          % dB
NUM_TRIALS = 50;
ATTENUATION = 80;               % What was the OTA attenuation?

max_evm_thresh = 50;            % discard trials w/ EVM % > this.

%% I forgot to adjust the Tx/Rx serial number vectors in the second experiment
% This code just switches the Tx and Rx serial numbers of the saved
% experiment struct. It only needed to be run once and never again, but I'm
% saving this comment/code here for posterity and to remind me what I did.
% REG
if (0)
    clear;
    load tx_evm_round_3_experiment_2
    % refactor Tx and Rx serials
   S = size(EXP_RESULTS);
   for ii = 1:1:S(1)
       for jj = 1:1:S(2)
            temp = EXP_RESULTS(ii, jj).tx_serial;
            EXP_RESULTS(ii, jj).tx_serial =  EXP_RESULTS(ii, jj).rx_serial;
            EXP_RESULTS(ii, jj).rx_serial = temp;
       end
   end
    save tx_evm_round_3_experiment_2
end


%% Process Each Result

for exp_ind = 1:1:NUM_TO_PLOT
    % Load Experiment Results
    exp = exp_strings{exp_ind};
    load(exp);
    
    evm = [];
    stddev_evm = [];
    rx_gain = [];

    % Format results
    for freq_i = 1:1:length(FREQ_VEC)
        center_freq = FREQ_VEC(freq_i);
        % Each gain
        for gain_i = 1:1:length(TX_GAIN_VEC)
            tx_gain = TX_GAIN_VEC(gain_i);

            % cull OOB trials...
            evms = EXP_RESULTS(freq_i, gain_i).rx_evm(EXP_RESULTS(freq_i, gain_i).rx_evm < max_evm_thresh);
            rx_gains = EXP_RESULTS(freq_i, gain_i).rx_gain(EXP_RESULTS(freq_i, gain_i).rx_evm < max_evm_thresh);
            % calculate trial statistics
            EXP_RESULTS(freq_i, gain_i).var_evm = var(evms);
            EXP_RESULTS(freq_i, gain_i).var_rx_gain = var(rx_gains);

            evm(freq_i, gain_i) = mean(evms);
            stddev_evm(freq_i, gain_i) = sqrt(var(evms));
            rx_gain(freq_i, gain_i) = mean(rx_gains);
            std_dev_rx_gain(freq_i, gain_i) = sqrt(var(rx_gains));
            %EXP_RESULTS(freq_i, gain_i).
        end      
        
        % find best tx_gain value for best evm_value
        [M, I] = min(evm(freq_i, :));
        min_evm(freq_i) = M;
        best_tx_gain(freq_i) = TX_GAIN_VEC(I(1));
    end


    %% Plot/Process Result
    if sum(ismember([1, 2, 3, 4, 5, 6], exp_ind)) 
        % Plot 1, 2 in Fig1, 3,4 in Fig2, etc...
        %Assumes all mat files are pairs
        figure(ceil(exp_ind/2))
        f_inds = 1:3:22;
        tx_gain_rep = repmat(TX_GAIN_VEC', [1, 22])';
        ax_a(exp_ind) = subplot(2, 2, mod(exp_ind-1, 2) + 1);
            errorbar(tx_gain_rep(f_inds, :)', evm(f_inds, :)', stddev_evm(f_inds, :)');
            hold on
           % plot(best_tx_gain, min_evm, '.r', 'MarkerSize', 16)
            for ind = 1:1:length(f_inds)
               leg_str{ind} = num2str(FREQ_VEC(f_inds(ind))/1000); 
            end
            title(sprintf('Rx EVM vs. Tx Gain\n%s --> %s, Atten = %d', EXP_RESULTS(1,1).tx_serial{1},  EXP_RESULTS(1,1).rx_serial{1}, ATTENUATION));
            legend(leg_str, 'Location', 'NorthWest');
            xlabel('Tx Gain (dB)');
            ylabel('Rx EVM (%)')
            ylim([0, 40]);
            grid on;
            hold off;
        ax_b(exp_ind) = subplot(2, 2, mod(exp_ind-1, 2) + 3);
            plot(tx_gain_rep(f_inds, :)', rx_gain(f_inds, :)', '.-' );%, std_dev_rx_gain(f_inds, :));
            hold on
            for ind = 1:1:length(f_inds)
               leg_str{ind} = num2str(FREQ_VEC(f_inds(ind))/1000); 
            end
            title(sprintf('Rx AGC Gain vs. Tx Gain\n%s --> %s, Atten = %d', EXP_RESULTS(1,1).tx_serial{1},  EXP_RESULTS(1,1).rx_serial{1}, ATTENUATION));
            xlabel('Tx Gain (dB)');
            ylabel('Rx Gain Setting (dB)')
            legend(leg_str, 'Location', 'NorthEast');
            ylim([0, 55]);
            xlim([14, 51]);
            grid on;
            hold off;
    end
    
    %%
    if exp_ind <= NUM_NEW_PLOTS
        plot_str = plot_strs{exp_ind};
        legend_str{exp_ind} = EXP_RESULTS(1,1).tx_serial{1};
    else
        plot_str = '.-b';
    end
    
    figure(100)
    ax_c(exp_ind) = subplot(2, 1, 1);
        plot(FREQ_VEC/1000, best_tx_gain, plot_str, 'LineWidth', 2, 'MarkerSize', 10);
        hold on;
        title(sprintf('Optimal Tx Gain vs. Center Frequency\n%s --> %s, Atten = %d', EXP_RESULTS(1,1).tx_serial{1},  EXP_RESULTS(1,1).rx_serial{1}, ATTENUATION))
        xlabel('Frequency (MHz)');
        ylabel('Optimal Tx Gain Setting (dB)');
        ylim([24, 38])
        grid on;
        legend(legend_str);
    ax_d(exp_ind) = subplot(2, 1, 2);
        plot(FREQ_VEC/1000, min_evm, plot_str);
        title(sprintf('Optimal EVM vs. Center Frequency\n%s --> %s, Atten = %d', EXP_RESULTS(1,1).tx_serial{1},  EXP_RESULTS(1,1).rx_serial{1}, ATTENUATION))
        xlabel('Frequency (MHz)');
        ylabel('Optimal EVM (%)')
        ylim([0, 14]);
        hold on;
        grid on;
        legend(legend_str);
end
% linkaxes(ax_a, 'y');
% linkaxes(ax_b, 'y');
% linkaxes([ax_a, ax_b], 'x')
linkaxes(ax_c, 'y');
linkaxes(ax_d, 'y');