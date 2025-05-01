function amplifier_chain_optimizer()
    clc; clear;
    fprintf('--- Amplifier Chain Noise Optimizer ---\n');
    % Input number of amplifiers
    n = input('Enter the number of amplifiers: ');

    amps = struct('gain_dB', {}, 'NF_dB', {});

    % User enters amplifiers
    for i = 1:n
        fprintf('Amplifier %d:\n', i);
        amps(i).gain_dB = input('  Enter Gain (in dB): ');
        amps(i).NF_dB = input('  Enter Noise Figure (in dB): ');
    end

    % Input noise power
    Pin_dBm = input('Enter input power (in dBm): ');
    Pin_noise_dBm = input('Enter input noise power (in dBm): ');

    % --- Compute for original user-entered configuration ---
    gains_user = 10.^(arrayfun(@(x) x.gain_dB, amps) / 10);
    NFs_user = 10.^(arrayfun(@(x) x.NF_dB, amps) / 10);
    nf_total_user = NFs_user(1);
    gain_product_user = 1;
    
    for i = 2:n
        gain_product_user = gain_product_user * gains_user(i-1);
        nf_total_user = nf_total_user + (NFs_user(i) - 1) / gain_product_user;
    end

    NF_total_dB_user = 10 * log10(nf_total_user);
    G_total_dB_user = sum(arrayfun(@(x) x.gain_dB, amps));
    Pout_user = Pin_dBm + G_total_dB_user;
    Pout_noise_user = Pin_noise_dBm + G_total_dB_user + NF_total_dB_user;

    fprintf('\n--- USER CONFIGURATION ---\n');
    for i = 1:n
        fprintf('  Amp %d → Gain: %.2f dB, NF: %.2f dB\n', i, amps(i).gain_dB, amps(i).NF_dB);
    end
    fprintf('Total Gain: %.2f dB\n', G_total_dB_user);
    fprintf('Total Noise Figure: %.2f dB\n', NF_total_dB_user);
    fprintf('Output Power (Pout): %.2f dBm\n', Pout_user);
    fprintf('Output Power (Pout): %.2f dBm\n', Pout_noise_user);

    % --- Find optimal configuration ---
    perms_idx = perms(1:n);
    num_perms = size(perms_idx, 1);
    min_nf_total = inf;
    best_order = [];

    for p = 1:num_perms
        idx = perms_idx(p, :);
        gains = 10.^(arrayfun(@(x) amps(x).gain_dB, idx) / 10);
        NFs = 10.^(arrayfun(@(x) amps(x).NF_dB, idx) / 10);

        nf_total = NFs(1);
        gain_product = 1;

        for j = 2:n
            gain_product = gain_product * gains(j-1);
            nf_total = nf_total + (NFs(j) - 1) / gain_product;
        end

        if nf_total < min_nf_total
            min_nf_total = nf_total;
            best_order = idx;
        end
    end

    NF_best_dB = 10 * log10(min_nf_total);
    G_best_dB = sum(arrayfun(@(x) amps(x).gain_dB, best_order));
    Pout_best = Pin_dBm + G_best_dB;
    Pout_noise_best = Pin_noise_dBm + G_best_dB + NF_best_dB;

    fprintf('\n--- BEST CONFIGURATION (Lowest NF) ---\n');
    for i = 1:n
        idx = best_order(i);
        fprintf('  Amp %d → Gain: %.2f dB, NF: %.2f dB\n', i, amps(idx).gain_dB, amps(idx).NF_dB);
    end
    fprintf('Total Gain: %.2f dB\n', G_best_dB);
    fprintf('Total Noise Figure: %.2f dB\n', NF_best_dB);
    fprintf('Output Power (Pout): %.2f dBm\n', Pout_best);
    fprintf('Output Noise Power minimum (PNo): %.2f dBm\n', Pout_noise_best);
end

%% function amplifier_configuration()
amplifier_chain_optimizer()