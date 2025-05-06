%Function to produce and plot additive white Gaussian noise for a given
%noise power
function plot_awgn(P_dBm)
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

    % Plotting 
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
end