package me.realimpact.telecom.calculation.policy.monthlyfee.domain;

import me.realimpact.telecom.calculation.domain.monthlyfee.CalculationMethod;
import me.realimpact.telecom.calculation.domain.monthlyfee.Pricing;

public interface MonthlyChargingPolicyFactory {
    Pricing getPolicy(CalculationMethod calculationMethod);
}
