package me.realimpact.telecom.calculation.policy.onetimecharge.port;

import me.realimpact.telecom.calculation.policy.onetimecharge.domain.installation.InstallationHistory;

import java.time.LocalDate;
import java.util.List;

public interface InstallationHistoryQueryPort {
    List<InstallationHistory> findInstallations(List<Long> contractIds, LocalDate billingStartDate, LocalDate billingEndDate);
}
