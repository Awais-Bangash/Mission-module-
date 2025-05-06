%Function to produce and plot additive white Gaussian noise for a given
%noise power
%Takes parameters: noise power in dBm, boolean on using bp filter, bp
%filter lower edge, bp filter upper edge
function plot_awgn(P_dBm, useBP, bp_f1, bp_f2, useLP, lp_fc)
    % Realistic real-world analog sampling frequency
    fs_analog = 200E9;
    
    % Zero padding
    zero_pad = 100000;
    
    % free space impedance
    w = 1/(2*377);
 
    % Creating the time vector
    t_end = 1E6/fs_analog; 
    t_analog = 0:1/fs_analog:t_end;
    
    % AWGN generation
    awgn = sqrt( 10.^((P_dBm - 30)/10) * 50 ) .* randn(fs_analog/1E6,1);   % AWGN with power P_dBm on 50 ohm line
    
    Ns         = length(awgn);                   % number of samples
    Fs         = 1/mean(diff(t_analog));         % sample‑rate from time vector
    MagFFT_analog = 2*abs(fftshift(fft(awgn, Ns+zero_pad))/Ns);
    freq_analog   = linspace(-Fs/2, Fs/2, Ns+zero_pad);

    MagFFT_analog_dBm = 10*log10(w.*MagFFT_analog.^2) + 30;

    % Bandpass Filter
    if useBP
        [b,a] = butter(5, [bp_f1 bp_f2]/(fs_analog/2), 'bandpass');
        awgn_bp = filtfilt(b, a, awgn);   % zero‑phase filtered noise
        MagFFT_bp        = 2*abs(fftshift(fft(awgn_bp, Ns+zero_pad))/Ns);
        MagFFT_bp_dBm    = 10*log10(w.*MagFFT_bp.^2) + 30;
    end

    % Lowpass Filter
    if useLP
        [bl, al] = butter(5, lp_fc/(fs_analog/2), 'low');   % 5th‑order LPF
        awgn_lp  = filtfilt(bl, al, awgn);                 % zero‑phase output
        MagFFT_lp     = 2*abs(fftshift(fft(awgn_lp, Ns+zero_pad))/Ns);
        MagFFT_lp_dBm = 10*log10(w .* MagFFT_lp.^2) + 30;
    end


    % Plotting    
    subplot(3, 1, 1);
    max_val = max(MagFFT_analog_dBm); 
    min_val = min(MagFFT_analog_dBm);
    ylimFD = [min_val-10 max_val+10]; % Automatic scaling to output AWGN
    xlimFD = [-100 100];
    plot(freq_analog/1E9, MagFFT_analog_dBm, 'LineWidth', 2.5)
    grid on; grid minor;
    set(gca, 'FontSize', 18)
    xlabel('Frequency [GHz]', 'FontSize',20)
    ylabel('AWGN Power [dBm]', 'FontSize',20)
    title('AWGN Spectra','FontSize',20)
    xlim(xlimFD)
    ylim(ylimFD);

    if useBP
        max_val = max(MagFFT_bp_dBm); 
        min_val = min(MagFFT_bp_dBm);
        ylimFD = [min_val-10 max_val+10]; % Automatic scaling to output AWGN
        xlimFD = [-100 100];
        subplot(3, 1, 2);
        plot(freq_analog/1E9, MagFFT_bp_dBm, 'r', 'LineWidth', 2.5)
        grid on; grid minor;
        set(gca, 'FontSize', 18)
        xlabel('Frequency [GHz]', 'FontSize',20)
        ylabel('AWGN Power [dBm]', 'FontSize',20)
        title('AWGN Spectra with Bandpass Filter','FontSize',20)
        xlim(xlimFD);
        ylim(ylimFD);
        xline(bp_f1/1e9, '--k', 'LineWidth', 2.5); % Plot BP filter range
        xline(bp_f2/1e9, '--k', 'LineWidth', 2.5);
        xline(-bp_f1/1e9, '--k', 'LineWidth', 2.5);
        xline(-bp_f2/1e9, '--k', 'LineWidth', 2.5);
    end

    if useLP
        max_val = max(MagFFT_lp_dBm); 
        min_val = min(MagFFT_lp_dBm);
        ylimFD = [min_val-10 max_val+10]; % Automatic scaling to output AWGN
        xlimFD = [-100 100];
        subplot(3, 1, 3);
        plot(freq_analog/1E9, MagFFT_lp_dBm, 'r', 'LineWidth', 2.5)
        grid on; grid minor;
        set(gca, 'FontSize', 18)
        xlabel('Frequency [GHz]', 'FontSize',20)
        ylabel('AWGN Power [dBm]', 'FontSize',20)
        title('AWGN Spectra with Low-Pass Filter','FontSize',20)
        xlim(xlimFD);
        ylim(ylimFD);
        xline(lp_fc/1e9, '--k', 'LineWidth', 2.5); % Plot LP filter cutoff
        xline(-lp_fc/1e9, '--k', 'LineWidth', 2.5);
    end
end