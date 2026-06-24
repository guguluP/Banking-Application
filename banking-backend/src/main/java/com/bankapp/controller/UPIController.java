package com.bankapp.controller;

import com.bankapp.model.UPITransaction;
import com.bankapp.repository.UPITransactionRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@RestController
@RequestMapping("/api/upi")
@PreAuthorize("hasRole('USER')")
public class UPIController {
    @Autowired
    private UPITransactionRepository upiTransactionRepository;
    
    @PostMapping("/pay")
    public ResponseEntity<?> payUPI(
            @RequestParam String accountId,
            @RequestParam String upiId,
            @RequestParam BigDecimal amount,
            @RequestParam(required = false) String remarks
    ) {
        UPITransaction txn = new UPITransaction();
        txn.setId("upi_" + UUID.randomUUID().toString().substring(0, 8));
        txn.setAccountId(accountId);
        txn.setUpiId(upiId);
        txn.setAmount(amount);
        txn.setRemarks(remarks);
        txn.setTransactionDate(LocalDateTime.now().toString());
        
        upiTransactionRepository.save(txn);
        
        return ResponseEntity.ok().body("{\"success\": true, \"message\": \"UPI payment successful\"}");
    }
    
    @GetMapping("/transactions/{accountId}")
    public ResponseEntity<?> getUPITransactions(@PathVariable String accountId) {
        return ResponseEntity.ok(upiTransactionRepository.findTop3ByAccountIdOrderByTransactionDateDesc(accountId));
    }
}