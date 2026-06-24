package com.bankapp.model;

import com.fasterxml.jackson.annotation.JsonValue;
import jakarta.persistence.*;
import java.math.BigDecimal;

@Entity
@Table(name = "accounts")
public class Account {
    @Id
    private String id;
    private String userId;
    private String accountNumber;

    @Enumerated(EnumType.STRING)
    private AccountType accountType;

    @Enumerated(EnumType.STRING)
    private AccountStatus accountStatus = AccountStatus.active;

    private BigDecimal balance = BigDecimal.ZERO;
    private BigDecimal availableBalance = BigDecimal.ZERO;
    private String currency = "INR";
    private String nickname;
    private String openedDate;
    private BigDecimal interestRate;
    private Boolean isPrimary = false;

    public Account() {}

    public Account(String id, String userId, String accountNumber, AccountType accountType, AccountStatus accountStatus, BigDecimal balance, BigDecimal availableBalance, String currency, String nickname, String openedDate, BigDecimal interestRate, Boolean isPrimary) {
        this.id = id;
        this.userId = userId;
        this.accountNumber = accountNumber;
        this.accountType = accountType;
        this.accountStatus = accountStatus;
        this.balance = balance;
        this.availableBalance = availableBalance;
        this.currency = currency;
        this.nickname = nickname;
        this.openedDate = openedDate;
        this.interestRate = interestRate;
        this.isPrimary = isPrimary;
    }

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }
    public String getAccountNumber() { return accountNumber; }
    public void setAccountNumber(String accountNumber) { this.accountNumber = accountNumber; }
    public AccountType getAccountType() { return accountType; }
    public void setAccountType(AccountType accountType) { this.accountType = accountType; }
    public AccountStatus getAccountStatus() { return accountStatus; }
    public void setAccountStatus(AccountStatus accountStatus) { this.accountStatus = accountStatus; }
    public BigDecimal getBalance() { return balance; }
    public void setBalance(BigDecimal balance) { this.balance = balance; }
    public BigDecimal getAvailableBalance() { return availableBalance; }
    public void setAvailableBalance(BigDecimal availableBalance) { this.availableBalance = availableBalance; }
    public String getCurrency() { return currency; }
    public void setCurrency(String currency) { this.currency = currency; }
    public String getNickname() { return nickname; }
    public void setNickname(String nickname) { this.nickname = nickname; }
    public String getOpenedDate() { return openedDate; }
    public void setOpenedDate(String openedDate) { this.openedDate = openedDate; }
    public Double getInterestRate() { return interestRate; }
    public void setInterestRate(Double interestRate) { this.interestRate = interestRate; }
    public Boolean getIsPrimary() { return isPrimary; }
    public void setIsPrimary(Boolean isPrimary) { this.isPrimary = isPrimary; }

    public enum AccountType {
        checking, savings, credit;
        
        @JsonValue
        public String toJson() {
            return switch (this) {
                case checking -> "Checking";
                case savings -> "Savings";
                case credit -> "Credit Card";
            };
        }
    }
    
    public enum AccountStatus {
        active, inactive, frozen, closed;
        
        @JsonValue
        public String toJson() {
            return switch (this) {
                case active -> "Active";
                case inactive -> "Inactive";
                case frozen -> "Frozen";
                case closed -> "Closed";
            };
        }
    }
}
