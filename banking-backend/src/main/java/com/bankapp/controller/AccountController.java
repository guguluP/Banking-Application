package com.bankapp.controller;

import com.bankapp.model.Account;
import com.bankapp.service.AccountService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.math.BigDecimal;
import java.util.List;

@RestController
@RequestMapping("/api/accounts")
@PreAuthorize("hasRole('USER')")
public class AccountController {
    @Autowired
    private AccountService accountService;
    
    @GetMapping("/{userId}")
    public ResponseEntity<List<Account>> getAccounts(@PathVariable String userId) {
        return ResponseEntity.ok(accountService.getUserAccounts(userId));
    }
    
    @PostMapping("/{fromAccountId}/transfer")
    public ResponseEntity<?> transfer(
            @PathVariable String fromAccountId,
            @RequestParam String toAccountId,
            @RequestParam BigDecimal amount
    ) {
        boolean success = accountService.transfer(fromAccountId, toAccountId, amount);
        if (success) {
            return ResponseEntity.ok().body("{\"success\": true, \"message\": \"Transfer completed\"}");
        }
        return ResponseEntity.badRequest().body("{\"success\": false, \"message\": \"Transfer failed\"}");
    }
}