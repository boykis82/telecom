package me.realimpact.telecom.calculation.policy.monthlyfee.domain;

import me.realimpact.telecom.calculation.domain.monthlyfee.AdditionalBillingFactor;

public interface ProvidesAdditionalBillingDetails {
    AdditionalBillingFactor getAdditionalBillingFactors();
}
