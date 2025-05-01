function thermal_noise_power()
    clc;

    fprintf('--- Thermal Noise Power Calculator ---\n');

    % Boltzmann constant
    kB = 1.38064852e-23; % J/K

    % Ask user for system temperature
    T_ref = 290; % Default temperature in K
    T_sys = input(['Enter system temperature in Kelvin (default = ' num2str(T_ref) '): ']);
    if isempty(T_sys)
        T_sys = T_ref;
    end

    % Ask user for bandwidth
    bandwidth = input('Enter receiver bandwidth in Hz (e.g., 1e9 for 1 GHz): ');

    % Calculate thermal noise power in watts
    noise_power_W = kB * T_sys * bandwidth;

    % Convert to dBm
    thermal_noise_dBm = 10 * log10(noise_power_W / 1e-3);

    fprintf('Thermal Noise Power: %.2f dBm\n', thermal_noise_dBm);
end
