/* Additive FitAI role authentication and trainer assignment schema. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
  BEGIN TRANSACTION;
  IF OBJECT_ID(N'dbo.SchemaMigrations', N'U') IS NULL
    THROW 51000, 'Apply migration 001 before migration 002.', 1;
  IF EXISTS (SELECT 1 FROM dbo.SchemaMigrations WHERE MigrationId=N'002_role_auth_and_assignments')
  BEGIN COMMIT TRANSACTION; PRINT N'FitAI migration 002 is already applied.'; RETURN; END;

  ALTER TABLE dbo.UserIdentities ADD PasswordHash nvarchar(255) NULL;
  CREATE TABLE dbo.UserRoles (
    UserId nvarchar(128) NOT NULL,
    RoleCode varchar(10) NOT NULL,
    CreatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_UserRoles_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_UserRoles PRIMARY KEY(UserId),
    CONSTRAINT FK_UserRoles_Users FOREIGN KEY(UserId) REFERENCES dbo.Users(UserId),
    CONSTRAINT CK_UserRoles_Role CHECK(RoleCode IN ('ADMIN','TRAINER','USER'))
  );
  CREATE TABLE dbo.TrainerProfiles (
    UserId nvarchar(128) NOT NULL,
    Phone nvarchar(30) NULL,
    Specialization nvarchar(300) NOT NULL,
    ExperienceYears tinyint NULL,
    ApprovalStatus varchar(10) NOT NULL CONSTRAINT DF_TrainerProfiles_Approval DEFAULT('Pending'),
    CONSTRAINT PK_TrainerProfiles PRIMARY KEY(UserId),
    CONSTRAINT FK_TrainerProfiles_Users FOREIGN KEY(UserId) REFERENCES dbo.Users(UserId),
    CONSTRAINT CK_TrainerProfiles_Approval CHECK(ApprovalStatus IN ('Pending','Approved','Rejected')),
    CONSTRAINT CK_TrainerProfiles_Experience CHECK(ExperienceYears IS NULL OR ExperienceYears <= 60)
  );
  CREATE TABLE dbo.TrainerRequests (
    TrainerRequestId bigint IDENTITY(1,1) NOT NULL,
    UserId nvarchar(128) NOT NULL,
    PreferredTrainerId nvarchar(128) NULL,
    Notes nvarchar(500) NULL,
    RequestStatus varchar(10) NOT NULL CONSTRAINT DF_TrainerRequests_Status DEFAULT('Pending'),
    CreatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_TrainerRequests_Created DEFAULT SYSUTCDATETIME(),
    UpdatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_TrainerRequests_Updated DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_TrainerRequests PRIMARY KEY(TrainerRequestId),
    CONSTRAINT FK_TrainerRequests_User FOREIGN KEY(UserId) REFERENCES dbo.Users(UserId),
    CONSTRAINT FK_TrainerRequests_PreferredTrainer FOREIGN KEY(PreferredTrainerId) REFERENCES dbo.Users(UserId),
    CONSTRAINT CK_TrainerRequests_Status CHECK(RequestStatus IN ('Pending','Approved','Rejected','Assigned'))
  );
  CREATE INDEX IX_TrainerRequests_Status_Created ON dbo.TrainerRequests(RequestStatus,CreatedAtUtc);
  CREATE UNIQUE INDEX UX_TrainerRequests_OnePendingPerUser ON dbo.TrainerRequests(UserId) WHERE RequestStatus='Pending';
  CREATE TABLE dbo.TrainerAssignments (
    TrainerAssignmentId bigint IDENTITY(1,1) NOT NULL,
    UserId nvarchar(128) NOT NULL,
    TrainerId nvarchar(128) NOT NULL,
    TrainerRequestId bigint NULL,
    AssignedByUserId nvarchar(128) NOT NULL,
    AssignedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_TrainerAssignments_Assigned DEFAULT SYSUTCDATETIME(),
    EndedAtUtc datetime2(3) NULL,
    CONSTRAINT PK_TrainerAssignments PRIMARY KEY(TrainerAssignmentId),
    CONSTRAINT FK_TrainerAssignments_User FOREIGN KEY(UserId) REFERENCES dbo.Users(UserId),
    CONSTRAINT FK_TrainerAssignments_Trainer FOREIGN KEY(TrainerId) REFERENCES dbo.Users(UserId),
    CONSTRAINT FK_TrainerAssignments_Request FOREIGN KEY(TrainerRequestId) REFERENCES dbo.TrainerRequests(TrainerRequestId),
    CONSTRAINT FK_TrainerAssignments_Admin FOREIGN KEY(AssignedByUserId) REFERENCES dbo.Users(UserId),
    CONSTRAINT CK_TrainerAssignments_End CHECK(EndedAtUtc IS NULL OR EndedAtUtc >= AssignedAtUtc)
  );
  CREATE UNIQUE INDEX UX_TrainerAssignments_ActiveUser ON dbo.TrainerAssignments(UserId) WHERE EndedAtUtc IS NULL;
  CREATE INDEX IX_TrainerAssignments_Trainer_Active ON dbo.TrainerAssignments(TrainerId,EndedAtUtc,UserId);
  CREATE TABLE dbo.AdminAuditEvents (
    AdminAuditEventId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_AdminAuditEvents PRIMARY KEY,
    AdminUserId nvarchar(128) NOT NULL,
    EventType varchar(40) NOT NULL,
    SubjectUserId nvarchar(128) NULL,
    Details nvarchar(500) NULL,
    CreatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_AdminAuditEvents_Created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_AdminAuditEvents_Admin FOREIGN KEY(AdminUserId) REFERENCES dbo.Users(UserId),
    CONSTRAINT FK_AdminAuditEvents_Subject FOREIGN KEY(SubjectUserId) REFERENCES dbo.Users(UserId)
  );
  CREATE INDEX IX_AdminAuditEvents_Created ON dbo.AdminAuditEvents(CreatedAtUtc DESC);
  INSERT dbo.SchemaMigrations(MigrationId) VALUES(N'002_role_auth_and_assignments');
  COMMIT TRANSACTION;
  PRINT N'FitAI migration 002 applied successfully.';
END TRY
BEGIN CATCH
  IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
  THROW;
END CATCH;
