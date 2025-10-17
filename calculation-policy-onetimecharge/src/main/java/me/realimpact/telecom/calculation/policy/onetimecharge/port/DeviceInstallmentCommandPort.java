package me.realimpact.telecom.calculation.policy.onetimecharge.port;

import me.realimpact.telecom.calculation.policy.onetimecharge.domain.installment.DeviceInstallmentMaster;

public interface DeviceInstallmentCommandPort {
    void updateChargeStatus(DeviceInstallmentMaster deviceInstallmentMaster);
}
