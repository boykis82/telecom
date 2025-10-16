package me.realimpact.telecom.calculation.domain;

import java.time.LocalDate;

public record CalculationContext(
        LocalDate billingStartDate,
        LocalDate billingEndDate,
        BillingCalculationType billingCalculationType,
        BillingCalculationPeriod billingCalculationPeriod) {
}
