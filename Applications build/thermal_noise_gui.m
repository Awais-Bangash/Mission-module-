function thermal_noise_gui()
    % Create UI Figure
    fig = uifigure('Name', 'Thermal Noise Power Calculator', 'Position', [100 100 400 300]);

    % Temperature input
    uilabel(fig, 'Position', [20 220 160 22], 'Text', 'System Temperature (K):');
    tempInput = uieditfield(fig, 'numeric', 'Position', [190 220 170 22], 'Value', 290);

    % Bandwidth input
    uilabel(fig, 'Position', [20 180 160 22], 'Text', 'Receiver Bandwidth (Hz):');
    bwInput = uieditfield(fig, 'numeric', 'Position', [190 180 170 22]);

    % Button to calculate
    calcBtn = uibutton(fig, 'push', ...
        'Text', 'Calculate', ...
        'Position', [140 130 120 30], ...
        'ButtonPushedFcn', @(btn,event) calculateNoise());

    % Output area
    resultArea = uitextarea(fig, ...
        'Position', [20 20 360 90], ...
        'Editable', 'off');

    % Core calculation logic
    function calculateNoise()
        kB = 1.38064852e-23; % Boltzmann constant

        T_sys = tempInput.Value;
        bandwidth = bwInput.Value;

        % Input validation
        if isempty(T_sys) || T_sys <= 0
            resultArea.Value = {'Error: Invalid temperature value.'};
            return;
        end
        if isempty(bandwidth) || bandwidth <= 0
            resultArea.Value = {'Error: Invalid bandwidth value.'};
            return;
        end

        % Compute noise power in W and convert to dBm
        noise_power_W = kB * T_sys * bandwidth;
        thermal_noise_dBm = 10 * log10(noise_power_W / 1e-3);

        % Display results
        resultArea.Value = {
            sprintf('System Temperature: %.2f K', T_sys)
            sprintf('Bandwidth: %.2f Hz', bandwidth)
            sprintf('Thermal Noise Power: %.2f dBm', thermal_noise_dBm)
        };
    end
end
