package me.realimpact.telecom.calculation.policy.monthlyfee.adapter;

import lombok.RequiredArgsConstructor;
import me.realimpact.telecom.calculation.policy.monthlyfee.domain.ContractWithProductsAndSuspensions;
import me.realimpact.telecom.calculation.policy.monthlyfee.adapter.mybatis.ProductQueryMapper;
import me.realimpact.telecom.calculation.policy.monthlyfee.converter.ContractDtoToDomainConverter;
import me.realimpact.telecom.calculation.policy.monthlyfee.dto.ContractProductsSuspensionsDto;
import me.realimpact.telecom.calculation.policy.monthlyfee.port.ProductQueryPort;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
@RequiredArgsConstructor
@Qualifier("default_product_query_repository")
public class ProductQueryRepository implements ProductQueryPort {
    private final ProductQueryMapper productQueryMapper;
    private final ContractDtoToDomainConverter converter;

    @Override
    public List<ContractWithProductsAndSuspensions> findContractsAndProductInventoriesByContractIds(
        List<Long> contractIds, LocalDate billingStartDate, LocalDate billingEndDate
    ) {
        List<ContractProductsSuspensionsDto> contractProductsSuspensionsDtos = productQueryMapper.findContractsAndProductInventoriesByContractIds(contractIds, billingStartDate, billingEndDate);
        return converter.convertToContracts(contractProductsSuspensionsDtos);
    }
}
