function general_chain_gui()
    % Create GUI window
    fig = uifigure('Name','RF Chain Optimizer','Position',[100 100 650 650]);
    
    uilabel(fig,'Position',[30 620 400 22], ...
        'Text','Note: Element 1 is closest to the receiver antenna.', ...
        'FontWeight','bold');

    % UI components
    uilabel(fig,'Position',[30 590 180 22],'Text','Number of Elements:');
    nField = uieditfield(fig,'numeric','Position',[200 590 100 22]);

    % Button to generate input fields
    uibutton(fig,'Text','Generate Fields','Position',[320 590 120 22], ...
        'ButtonPushedFcn', @(btn,event) generateFields(fig, nField.Value));
end

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
    uilabel(ampPanel, 'Position', [10 startY 150 22], 'Text', 'Input Signal Power (dBm):');
    uieditfield(ampPanel, 'numeric', 'Tag', 'PinField', 'Position', [160 startY 70 22]);

    startY = startY - spacingY;

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
        'Total Gain: %.2f dB\n' ...
        'Total Noise Figure: %.2f dB\n' ...
        'Output Power: %.2f dBm\n' ...
        'Output Noise Power: %.2f dBm\n\n' ...
        'SNR = %.2f dB\n\n' ...
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
        'Output Power: %.2f dBm\n' ...
        'Output Noise: %.2f dBm\n' ...
        'SNR Best = %.2f dB\n'], ...
        msg, G_best_dB, NF_best_dB, Pout_best, Pout_noise_best, SNR_BEST_OUT);

    uialert(fig, msg, 'Calculation Results');
end
