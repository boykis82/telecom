package me.realimpact.telecom.calculation.policy.monthlyfee.port;

import me.realimpact.telecom.calculation.domain.BillingCalculationType;

/**
 * ProductQueryPort 구현체를 BillingCalculationType별로 해결하는 인터페이스
 */
public interface ProductQueryPortResolver {

    /**
     * BillingCalculationType에 따른 적절한 ProductQueryPort 구현체 반환
     *
     * @param billingCalculationType 청구 계산 유형
     * @return 해당 유형에 맞는 ProductQueryPort
     */
    ProductQueryPort getProductQueryPort(BillingCalculationType billingCalculationType);
}
