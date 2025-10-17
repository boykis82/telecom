
package me.realimpact.telecom.billing.web;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication(scanBasePackages = {"me.realimpact.telecom.calculation", "me.realimpact.telecom.billing.web"})
@MapperScan(basePackages = {
        "me.realimpact.telecom.calculation.infrastructure.adapter.mybatis",
        "me.realimpact.telecom.calculation.policy.monthlyfee.adapter.mybatis",
        "me.realimpact.telecom.calculation.policy.onetimecharge.adapter.mybatis"
})
public class WebServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(WebServiceApplication.class, args);
    }

}


