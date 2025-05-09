function general_chain_gui()
    % Create GUI window
    fig = uifigure('Name','RF Chain Optimizer','Position',[100 100 650 650]);
    
    uilabel(fig,'Position',[30 620 400 22], ...
        'Text','Note: Element 1 is closest to the receiver antenna.', ...
        'FontWeight','bold');

    % Number of elements
    uilabel(fig,'Position',[30 590 180 22],'Text','Number of Elements:');
    nField = uieditfield(fig,'numeric','Position',[200 590 100 22]);

    %% Filter options
    % Bandpass filter checkbox
    bpCheck = uicheckbox(fig, 'Text', 'Use Bandpass Filter', ...
        'Position', [30 550 150 22], 'Value', true, 'Tag', 'BPCheck');

    % Bandpass frequency inputs
    uilabel(fig,'Position',[200 550 100 22],'Text','BP f1 (Hz):');
    bpF1Field = uieditfield(fig,'numeric','Position',[280 550 80 22], 'Tag', 'BPF1');
    uilabel(fig,'Position',[370 550 100 22],'Text','BP f2 (Hz):');
    bpF2Field = uieditfield(fig,'numeric','Position',[450 550 80 22], 'Tag', 'BPF2');

    % Lowpass filter checkbox
    lpCheck = uicheckbox(fig, 'Text', 'Use Lowpass Filter', ...
        'Position', [30 520 150 22], 'Value', true, 'Tag', 'LPCheck');

    % Lowpass cutoff input
    uilabel(fig,'Position',[200 520 130 22],'Text','LP Cutoff (Hz):');
    lpFcField = uieditfield(fig,'numeric','Position',[330 520 100 22], 'Tag', 'LPFC');

    % Generate button
    uibutton(fig,'Text','Generate Fields','Position',[250 450 120 40], ...
        'ButtonPushedFcn', @(btn,event) generateFields(fig, nField.Value));
end

%%generate fields button pressed
function generateFields(fig, n)
    % Clear previous panel if it exists
    delete(findall(fig, 'Tag', 'AmpPanel'));

    % Create scrollable panel
    panelHeight = max(350, 100 + n * 40);
    startY = panelHeight - 60;

    ampPanel = uipanel(fig, 'Title', 'RF Chain Parameters', ...
        'Position', [20 80 610 panelHeight], ...
        'Tag', 'AmpPanel', ...
        'Scrollable', 'on');

    spacingY = 30;

    % Temperature input
    uilabel(ampPanel, 'Position', [10 startY 180 22], 'Text', 'System Temperature (K):');
    tempField = uieditfield(ampPanel, 'numeric', 'Tag', 'TempField', ...
        'Position', [200 startY 100 22], 'Value', 290);

    % Bandwidth input
    uilabel(ampPanel, 'Position', [320 startY 160 22], 'Text', 'Bandwidth (Hz):');
    bwField = uieditfield(ampPanel, 'numeric', 'Tag', 'BWField', ...
        'Position', [470 startY 100 22]);

    startY = startY - spacingY;

    % Input signal power
    uilabel(ampPanel, 'Position', [10 startY 200 22], 'Text', 'Input Signal Power(dBm) for SNR:');
    uieditfield(ampPanel, 'numeric', 'Tag', 'PinField', 'Position', [200 startY 70 22]);

    startY = startY - spacingY;
    %% Create fields based user entered inputs 
    for i = 1:n
        y = startY - (i - 1) * spacingY;

        % Name
        uilabel(ampPanel, 'Position', [10 y 60 22], ...
            'Text', sprintf('Element %d:', i));
        uieditfield(ampPanel, 'text', 'Tag', sprintf('nameField%d', i), ...
            'Position', [75 y 80 22]);

        % Gain
        uilabel(ampPanel, 'Position', [165 y 70 22], 'Text', 'Gain (dB):');
        uieditfield(ampPanel, 'numeric', 'Tag', sprintf('gainField%d', i), ...
            'Position', [240 y 60 22]);

        % NF
        uilabel(ampPanel, 'Position', [310 y 60 22], 'Text', 'NF (dB):');
        uieditfield(ampPanel, 'numeric', 'Tag', sprintf('nfField%d', i), ...
            'Position', [370 y 60 22]);
    end

    y = y - 60;

    % Calculate button
    uibutton(ampPanel, 'Text', 'Calculate', ...
        'Position', [20 y 100 30], ...
        'ButtonPushedFcn', @(btn,event) calculateNF(fig, n));
end
%%Calculate button pressed 
function calculateNF(fig, n)
    names = strings(1, n);
    gains_dB = zeros(1, n);
    NFs_dB = zeros(1, n);
    
    for i = 1:n
        nameField = findobj(fig, 'Tag', sprintf('nameField%d', i));
        gainField = findobj(fig, 'Tag', sprintf('gainField%d', i));
        nfField = findobj(fig, 'Tag', sprintf('nfField%d', i));
        names(i) = nameField.Value;
        gains_dB(i) = gainField.Value;
        NFs_dB(i) = nfField.Value;
    end

    % Read temperature and bandwidth
    T_sys = findobj(fig, 'Tag', 'TempField').Value;
    BW = findobj(fig, 'Tag', 'BWField').Value;

    % Calculate thermal noise power
    kB = 1.38064852e-23; % Boltzmann constant
    noise_power_W = kB * T_sys * BW;
    Pin_noise_dBm = 10 * log10(noise_power_W / 1e-3); % Convert to dBm

    % Read signal input power
    Pin_dBm = findobj(fig, 'Tag', 'PinField').Value;

    % Convert to linear gains and noise factor
    gains = 10.^(gains_dB / 10);
    NFs = 10.^(NFs_dB / 10);

    % User configuration values calculation
    NF_total_user = NFs(1);
    gain_product = 1;
    for i = 2:n
        gain_product = gain_product * gains(i-1);
        NF_total_user = NF_total_user + (NFs(i) - 1) / gain_product;
    end
    NF_user_dB = 10 * log10(NF_total_user);
    G_user_dB = sum(gains_dB);
    Pout_user = Pin_dBm + G_user_dB;
    Pout_noise_user = Pin_noise_dBm + G_user_dB + NF_user_dB;
    SNR_USER_OUT = Pout_user - Pout_noise_user;

    % Best configuration (minimum NF)
    perms_idx = perms(1:n);
    min_nf_total = inf;
    best_order = [];

    for p = 1:size(perms_idx, 1)
        idx = perms_idx(p, :);
        gains_perm = 10.^(gains_dB(idx) / 10);
        NFs_perm = 10.^(NFs_dB(idx) / 10);

        nf_total = NFs_perm(1);
        gp = 1;
        for j = 2:n
            gp = gp * gains_perm(j-1);
            nf_total = nf_total + (NFs_perm(j) - 1) / gp;
        end

        if nf_total < min_nf_total
            min_nf_total = nf_total;
            best_order = idx;
        end
    end

    NF_best_dB = 10 * log10(min_nf_total);
    G_best_dB = sum(gains_dB(best_order));
    Pout_best = Pin_dBm + G_best_dB;
    Pout_noise_best = Pin_noise_dBm + G_best_dB + NF_best_dB;
    SNR_BEST_OUT = Pout_best - Pout_noise_best;
    
    % Build result message
    msg = sprintf(['--- USER CONFIGURATION ---\n' ...
        'Total Gain (Your configuration): %.2f dB\n' ...
        'Total Noise Figure (Your configuration): %.2f dB\n' ...
        'Output Power (Your configuration): %.2f dBm\n' ...
        'Output Noise (Your configuration): %.2f dBm\n\n' ...
        'SNR you get (Your configuration)= %.2f dB\n\n' ...
        '--- BEST CONFIGURATION (Min NF) ---\n'...
        'Note that the ideal configuration may not always be Realistic\n'], ...
        G_user_dB, NF_user_dB, Pout_user, Pout_noise_user, SNR_USER_OUT);

    for i = 1:n
        idx = best_order(i);
        msg = sprintf('%sElement %d (%s): Gain = %.2f dB, NF = %.2f dB\n', ...
            msg, i, names(idx), gains_dB(idx), NFs_dB(idx));
    end

    msg = sprintf(['%sTotal Gain: %.2f dB\n' ...
        'Total NF: %.2f dB\n' ...
        'Output Power (Best Configuration) : %.2f dBm\n' ...
        'Output Noise (Best Configuration): %.2f dBm\n\n' ...
        'SNR Best you can get (Best Configuration)= %.2f dB\n'], ...
        msg, G_best_dB, NF_best_dB, Pout_best, Pout_noise_best, SNR_BEST_OUT);

    uialert(fig, msg, 'Calculation Results');
    useBP = findobj(fig, 'Tag', 'BPCheck').Value;
    bp_f1 = findobj(fig, 'Tag', 'BPF1').Value;
    bp_f2 = findobj(fig, 'Tag', 'BPF2').Value;

    useLP = findobj(fig, 'Tag', 'LPCheck').Value;
    lp_fc = findobj(fig, 'Tag', 'LPFC').Value;
    
    figure;
    plot_awgn_signal(BW, Pout_noise_user, useBP, bp_f1, bp_f2, useLP, lp_fc, false)
    figure;
    plot_awgn_signal(BW, Pout_noise_best, useBP, bp_f1, bp_f2, useLP, lp_fc, true)
end


%% AWGN
%Function to produce and plot additive white Gaussian noise for a given
%noise power
%Takes parameters: noise power in dBm, boolean on using bp filter, bp
%filter lower edge, bp filter upper edge
function plot_awgn_signal(bandwidth, P_dBm, useBP, bp_f1, bp_f2, useLP, lp_fc, best)
    % Realistic real-world analog sampling frequency
    fs_analog = 2*bandwidth;
    
    % Zero padding
    zero_pad = 100000;
    
    % free space impedance
    w = 1/(2*377);
 
    % Creating the time vector
    t_end = 1E6/fs_analog; 
    t_analog = 0:1/fs_analog:t_end;
    
    % awgn_signal generation
    awgn_signal = sqrt(10.^((P_dBm + 30)/10) * 50) .* randn(150E9/1E6,1);   % awgn_signal with power P_dBm on 50 ohm line


    Ns         = length(awgn_signal);                   % number of samples
    Fs         = 1/mean(diff(t_analog));         % sample‑rate from time vector
    MagFFT_analog = 2*abs(fftshift(fft(awgn_signal, Ns+zero_pad))/Ns);
    freq_analog   = linspace(-Fs/2, Fs/2, Ns+zero_pad);

    MagFFT_analog_dBm = 10*log10(w.*MagFFT_analog.^2) + 30;
    
    disp(mean(MagFFT_analog_dBm))

    % Bandpass Filter
    if useBP
        [b,a] = butter(5, [bp_f1 bp_f2]/(fs_analog/2), 'bandpass');
        awgn_signal_bp = filtfilt(b, a, awgn_signal);   % zero‑phase filtered noise
        MagFFT_bp        = 2*abs(fftshift(fft(awgn_signal_bp, Ns+zero_pad))/Ns);
        MagFFT_bp_dBm    = 10*log10(w.*MagFFT_bp.^2) + 30;
    end

    % Lowpass Filter
    if useLP
        [bl, al] = butter(5, lp_fc/(fs_analog/2), 'low');   % 5th‑order LPF
        awgn_signal_lp  = filtfilt(bl, al, awgn_signal);                 % zero‑phase output
        MagFFT_lp     = 2*abs(fftshift(fft(awgn_signal_lp, Ns+zero_pad))/Ns);
        MagFFT_lp_dBm = 10*log10(w .* MagFFT_lp.^2) + 30;
    end


    % Plotting    
    subplot(3, 1, 1);
    max_val = max(MagFFT_analog_dBm); 
    min_val = min(MagFFT_analog_dBm);
    ylimFD = [min_val-10 max_val+10]; % Automatic scaling to output awgn_signal
    xlimFD = [0 bandwidth/1e9];
    plot(freq_analog/1E9, MagFFT_analog_dBm, 'LineWidth', 2.5)
    grid on; grid minor;
    set(gca, 'FontSize', 18)
    xlabel('Frequency [GHz]', 'FontSize',20)
    ylabel('AWGN Signal Power [dBm]', 'FontSize',20)
    title('AWGN Signal Spectra','FontSize',20)
    if(best)
            title('AWGN Signal Spectra (Best Configuration)','FontSize',20)
    end
    xlim(xlimFD)
    ylim(ylimFD);
    yline(P_dBm, 'g', 'Output Noise Power')

    if useBP
        max_val = max(MagFFT_bp_dBm); 
        min_val = min(MagFFT_bp_dBm);
        ylimFD = [min_val-10 max_val+10]; % Automatic scaling to output awgn_signal
        xlimFD = [0 bandwidth/1e9];
        subplot(3, 1, 2);
        plot(freq_analog/1E9, MagFFT_bp_dBm, 'r', 'LineWidth', 2.5)
        grid on; grid minor;
        set(gca, 'FontSize', 18)
        xlabel('Frequency [GHz]', 'FontSize',20)
        ylabel('AWGN Signal Power [dBm]', 'FontSize',20)
        title('AWGN Signal Spectra with Bandpass Filter','FontSize',20)
        if(best)
            title('AWGN Signal Spectra with Bandpass Filter (Best Configuration)','FontSize',20)
        end
        xlim(xlimFD);
        ylim(ylimFD);
        xline(bp_f1/1e9, '--k', 'LineWidth', 2.5); % Plot BP filter range
        xline(bp_f2/1e9, '--k', 'LineWidth', 2.5);
        xline(-bp_f1/1e9, '--k', 'LineWidth', 2.5);
        xline(-bp_f2/1e9, '--k', 'LineWidth', 2.5);
        yline(P_dBm, 'g', 'Output Noise Power')
    end

    if useLP
        max_val = max(MagFFT_lp_dBm); 
        min_val = min(MagFFT_lp_dBm);
        ylimFD = [min_val-10 max_val+10]; % Automatic scaling to output awgn_signal
        xlimFD = [0 bandwidth/1e9];
        subplot(3, 1, 3);
        plot(freq_analog/1E9, MagFFT_lp_dBm, 'm', 'LineWidth', 2.5)
        grid on; grid minor;
        set(gca, 'FontSize', 18)
        xlabel('Frequency [GHz]', 'FontSize',20)
        ylabel('AWGN Signal Power [dBm]', 'FontSize',20)
        title('AWGN Signal Spectra with Low-Pass Filter','FontSize',20)
        if(best)
            title('AWGN Signal Spectra with Low-Pass Filter (Best Configuration)','FontSize',20)
        end
        xlim(xlimFD);
        ylim(ylimFD);
        xline(lp_fc/1e9, '--k', 'LineWidth', 2.5); % Plot LP filter cutoff
        xline(-lp_fc/1e9, '--k', 'LineWidth', 2.5);
        yline(P_dBm, 'g', 'Output Noise Power')
    end
end