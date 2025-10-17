package me.realimpact.telecom.calculation.policy.monthlyfee.port;

import me.realimpact.telecom.calculation.policy.monthlyfee.domain.ContractWithProductsAndSuspensions;

import java.time.LocalDate;
import java.util.List;

public interface ProductQueryPort {
    List<ContractWithProductsAndSuspensions> findContractsAndProductInventoriesByContractIds(
        List<Long> contractIds, LocalDate billingStartDate, LocalDate billingEndDate
    );
}
