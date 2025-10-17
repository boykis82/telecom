package me.realimpact.telecom.calculation.policy.onetimecharge.port;

import me.realimpact.telecom.calculation.policy.onetimecharge.domain.installation.InstallationHistory;
import me.realimpact.telecom.calculation.policy.onetimecharge.domain.installment.DeviceInstallmentMaster;

import java.time.LocalDate;
import java.util.List;

public interface DeviceInstallmentQueryPort {
    List<DeviceInstallmentMaster> findDeviceInstallments(List<Long> contractIds, LocalDate billingStartDate, LocalDate billingEndDate);
}
