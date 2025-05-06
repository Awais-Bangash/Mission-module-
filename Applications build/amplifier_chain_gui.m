function amplifier_chain_gui()
    % Create GUI window
    fig = uifigure('Name','Amplifier Chain Optimizer','Position',[100 100 600 600]);

    uilabel(fig,'Position',[30 575 400 22], ...
        'Text','Note: Element 1 is closest to the receiver antenna.', ...
        'FontWeight','bold');

    % UI components
    uilabel(fig,'Position',[30 550 180 22],'Text','Number of Amplifiers:');
    nField = uieditfield(fig,'numeric','Position',[200 550 100 22]);

    % Store fields globally
    setappdata(fig,'ampData',struct('ampFields',[]));

    btnGenerate = uibutton(fig,'Text','Generate Fields','Position',[320 550 120 22], ...
        'ButtonPushedFcn', @(btn,event) generateFields(fig, nField.Value));

end

function generateFields(fig, n)
    % Clear previous amplifier panel if it exists
    delete(findall(fig, 'Tag', 'AmpPanel'));

    % Compute required panel height
    panelHeight = max(250, 80 + n * 40);  % minimum 200, scales with amplifiers
    startY = panelHeight - 60;            % initial Y for first amplifier row

    % Create scrollable panel
    ampPanel = uipanel(fig, 'Title', 'Amplifier Parameters', ...
    'Position', [20 100 560 panelHeight], ...
    'Tag', 'AmpPanel', ...
    'Scrollable', 'on');

    spacingY = 20;  % space between rows

    % Store fields in app data for later use
    for i = 1:n
        y = startY - (i - 1) * spacingY;

        % Gain label and field
        uilabel(ampPanel, 'Position', [20 y 100 22], ...
            'Text', sprintf('Amp %d Gain (dB):', i));
        uieditfield(ampPanel, 'numeric', 'Tag', sprintf('gainField%d', i), ...
            'Position', [130 y 70 22]);

        % NF label and field
        uilabel(ampPanel, 'Position', [220 y 120 22], ...
            'Text', sprintf('Amp %d NF (dB):', i));
        uieditfield(ampPanel, 'numeric', 'Tag', sprintf('nfField%d', i), ...
            'Position', [340 y 70 22]);
    end

    % Input Power and Noise Power
    uilabel(ampPanel, 'Position', [20 y - 60 140 22], 'Text', 'Input Power (dBm):');
    uieditfield(ampPanel, 'numeric', 'Tag', 'PinField', 'Position', [160 y - 60 70 22]);

    uilabel(ampPanel, 'Position', [250 y - 60 150 22], 'Text', 'Input Noise Power (dBm):');
    uieditfield(ampPanel, 'numeric', 'Tag', 'PinNoiseField', 'Position', [400 y - 60 70 22]);

    % Calculate button
    uibutton(ampPanel, 'Text', 'Calculate', ...
        'Position', [20 y - 100 100 30], ...
        'ButtonPushedFcn', @(btn,event) calculateNF(fig, n));
end

function calculateNF(fig, n)
    gains_dB = zeros(1, n);
    NFs_dB = zeros(1, n);

    % Read gain and NF for each amplifier
    for i = 1:n
        gainField = findobj(fig, 'Tag', sprintf('gainField%d', i));
        nfField = findobj(fig, 'Tag', sprintf('nfField%d', i));
        gains_dB(i) = gainField.Value;
        NFs_dB(i) = nfField.Value;
    end

    % Read input power and noise power
    PinField = findobj(fig, 'Tag', 'PinField');
    PinNoiseField = findobj(fig, 'Tag', 'PinNoiseField');
    Pin_dBm = PinField.Value;
    Pin_noise_dBm = PinNoiseField.Value;

    % Convert to linear units
    gains = 10.^(gains_dB / 10);
    NFs = 10.^(NFs_dB / 10);

    % User configuration
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
    SNR_USER = Pout_user - Pout_noise_user;

    % Best configuration (permutation)
    perms_idx = perms(1:n);
    min_nf_total = inf;
    best_order = [];
    for p = 1:size(perms_idx, 1)
        idx = perms_idx(p, :);
        gains_perm = 10.^(gains_dB(idx) / 10);
        NFs_perm = 10.^(NFs_dB(idx) / 10);

        nf_total = NFs_perm(1);
        gain_product = 1;
        for j = 2:n
            gain_product = gain_product * gains_perm(j-1);
            nf_total = nf_total + (NFs_perm(j) - 1) / gain_product;
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
    SNR_BEST = Pout_best - Pout_noise_best;

    % Create result message
    msg = sprintf(['--- USER CONFIGURATION ---\n' ...
        'Total Gain: %.2f dB\n' ...
        'Total Noise Figure: %.2f dB\n' ...
        'Output Power: %.2f dBm\n' ...
        'Output Noise Power: %.2f dBm\n' ...
        'SNR User: %.2f\n\n'...
        '--- BEST CONFIGURATION (Min NF) ---\n'], ...
        G_user_dB, NF_user_dB, Pout_user, Pout_noise_user, SNR_USER);

    for i = 1:n
        idx = best_order(i);
        msg = sprintf('%sAmp %d: Gain = %.2f dB, NF = %.2f dB\n', ...
            msg, i, gains_dB(idx), NFs_dB(idx));
    end

    msg = sprintf('%sTotal Gain: %.2f dB\nTotal NF: %.2f dB\nOutput Power: %.2f dBm\nOutput Noise: %.2f dBm\n Best SNR : %.2f dB', ...
        msg, G_best_dB, NF_best_dB, Pout_best, Pout_noise_best, SNR_BEST);

    % Display everything
    uialert(fig, msg, 'Calculation Results');
end



function computeResult(fig, Pin_dBm, Pin_noise_dBm)
    appData = getappdata(fig,'ampData');
    amps = struct('gain_dB', {}, 'NF_dB', {});
    for i = 1:length(appData.ampFields)
        amps(i).gain_dB = appData.ampFields{i}.gain.Value;
        amps(i).NF_dB = appData.ampFields{i}.nf.Value;
    end

    % Convert to linear
    gains = 10.^(arrayfun(@(x) x.gain_dB, amps) / 10);
    NFs = 10.^(arrayfun(@(x) x.NF_dB, amps) / 10);
    nf_total = NFs(1);
    gain_product = 1;

    for i = 2:length(amps)
        gain_product = gain_product * gains(i-1);
        nf_total = nf_total + (NFs(i) - 1) / gain_product;
    end

    NF_total_dB_user = 10*log10(nf_total);
    G_total_dB_user = sum(arrayfun(@(x) x.gain_dB, amps));
    Pout = Pin_dBm + G_total_dB_user;
    Pout_noise = Pin_noise_dBm + G_total_dB_user + NF_total_dB_user;

    % Optimize configuration
    perms_idx = perms(1:length(amps));
    min_nf_total = inf;
    best_order = [];

    for p = 1:size(perms_idx,1)
        idx = perms_idx(p,:);
        g_perm = 10.^(arrayfun(@(x) amps(x).gain_dB, idx) / 10);
        nf_perm = 10.^(arrayfun(@(x) amps(x).NF_dB, idx) / 10);

        nf_total_perm = nf_perm(1);
        gp = 1;
        for j = 2:length(idx)
            gp = gp * g_perm(j-1);
            nf_total_perm = nf_total_perm + (nf_perm(j)-1)/gp;
        end
        if nf_total_perm < min_nf_total
            min_nf_total = nf_total_perm;
            best_order = idx;
        end
    end

    NF_best_dB = 10*log10(min_nf_total);
    G_best_dB = sum(arrayfun(@(x) amps(x).gain_dB, best_order));
    Pout_best = Pin_dBm + G_best_dB;
    Pout_noise_best = Pin_noise_dBm + G_best_dB + NF_best_dB;

    % Display result
    msg = sprintf('--- USER CONFIG ---\nTotal Gain: %.2f dB\nNF: %.2f dB\nOutput Power: %.2f dBm\nOutput Noise: %.2f dBm\n\n--- OPTIMIZED CONFIG ---\nOrder: %s\nTotal Gain: %.2f dB\nNF: %.2f dB\nOutput Power: %.2f dBm\nOutput Noise: %.2f dBm\n', ...
        G_total_dB_user, NF_total_dB_user, Pout, Pout_noise, ...
        mat2str(best_order), G_best_dB, NF_best_dB, Pout_best, Pout_noise_best);

    uialert(fig, msg, 'Computation Result');
end
