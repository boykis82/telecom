package me.realimpact.telecom.calculation.policy.onetimecharge.adapter;

import lombok.RequiredArgsConstructor;
import me.realimpact.telecom.calculation.policy.onetimecharge.domain.installation.InstallationHistory;
import me.realimpact.telecom.calculation.policy.onetimecharge.adapter.mybatis.InstallationHistoryMapper;
import me.realimpact.telecom.calculation.policy.onetimecharge.converter.OneTimeChargeDtoConverter;
import me.realimpact.telecom.calculation.policy.onetimecharge.dto.InstallationHistoryDto;
import me.realimpact.telecom.calculation.policy.onetimecharge.port.InstallationHistoryCommandPort;
import me.realimpact.telecom.calculation.policy.onetimecharge.port.InstallationHistoryQueryPort;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
@RequiredArgsConstructor
public class InstallationHistoryRepository implements InstallationHistoryQueryPort, InstallationHistoryCommandPort {
    private final InstallationHistoryMapper installationHistoryMapper;
    private final OneTimeChargeDtoConverter oneTimeChargeDtoConverter;

    @Override
    public List<InstallationHistory> findInstallations(
        List<Long> contractIds, LocalDate billingStartDate, LocalDate billingEndDate
    ) {
        List<InstallationHistoryDto> installationHistoryDtos =
            installationHistoryMapper.findInstallationsByContractIds(contractIds, billingEndDate);
        return oneTimeChargeDtoConverter.convertToInstallationHistories(installationHistoryDtos);
    }

    @Override
    public void updateChargeStatus(InstallationHistory installationHistory) {
        int updatedRows = installationHistoryMapper.updateBilledFlag(
            installationHistory.getContractId(),
            installationHistory.getSequenceNumber()
        );
        
        if (updatedRows == 0) {
            throw new IllegalStateException(
                "설치내역을 찾을 수 없습니다. contractId: " + installationHistory.getContractId() +
                ", sequenceNumber: " + installationHistory.getSequenceNumber()
            );
        }
    }
}
