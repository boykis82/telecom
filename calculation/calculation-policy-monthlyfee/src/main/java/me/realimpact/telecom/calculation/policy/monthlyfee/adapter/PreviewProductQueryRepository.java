package me.realimpact.telecom.calculation.policy.monthlyfee.adapter;

import lombok.RequiredArgsConstructor;
import me.realimpact.telecom.calculation.policy.monthlyfee.domain.ContractWithProductsAndSuspensions;
import me.realimpact.telecom.calculation.policy.monthlyfee.adapter.mybatis.PreviewProductQueryMapper;
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
@Qualifier("preview_product_query_repository")
public class PreviewProductQueryRepository implements ProductQueryPort {
    private final PreviewProductQueryMapper previewProductQueryMapper;
    private final ContractDtoToDomainConverter converter;

    @Override
    public List<ContractWithProductsAndSuspensions> findContractsAndProductInventoriesByContractIds(
            List<Long> contractIds, LocalDate billingStartDate, LocalDate billingEndDate
    ) {
        List<ContractProductsSuspensionsDto> contractProductsSuspensionsDtos =
                previewProductQueryMapper.findContractsAndProductInventoriesByContractIds(contractIds, billingEndDate);
        return converter.convertToContracts(contractProductsSuspensionsDtos);
    }
}
