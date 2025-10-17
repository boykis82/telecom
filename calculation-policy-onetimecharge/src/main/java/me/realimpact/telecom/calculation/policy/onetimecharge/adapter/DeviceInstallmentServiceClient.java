package me.realimpact.telecom.calculation.policy.onetimecharge.adapter;

import me.realimpact.telecom.calculation.policy.onetimecharge.domain.installment.DeviceInstallmentMaster;
import me.realimpact.telecom.calculation.policy.onetimecharge.port.DeviceInstallmentCommandPort;
import org.springframework.stereotype.Component;

@Component
public class DeviceInstallmentServiceClient implements DeviceInstallmentCommandPort {
    @Override
    public void updateChargeStatus(DeviceInstallmentMaster deviceInstallmentMaster) {
        // 오더의 서비스를 주입받아서 호출하거나 이벤트 발행 필요
    }
}
