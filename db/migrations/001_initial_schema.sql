/*
  FitAI migration 001: normalized Azure SQL schema.
  Additive only. Safe to rerun: dbo.SchemaMigrations prevents a second apply.
  No demo food or nutrition values are inserted by this migration.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.SchemaMigrations', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.SchemaMigrations
        (
            MigrationId nvarchar(100) NOT NULL,
            AppliedAtUtc datetime2(3) NOT NULL
                CONSTRAINT DF_SchemaMigrations_AppliedAtUtc DEFAULT SYSUTCDATETIME(),
            CONSTRAINT PK_SchemaMigrations PRIMARY KEY (MigrationId)
        );
    END;

    IF EXISTS (SELECT 1 FROM dbo.SchemaMigrations WHERE MigrationId = N'001_initial_schema')
    BEGIN
        COMMIT TRANSACTION;
        PRINT N'FitAI migration 001 is already applied.';
        RETURN;
    END;

    CREATE TABLE dbo.Users
    (
        UserId nvarchar(128) NOT NULL,
        Email nvarchar(320) NOT NULL,
        EmailVerifiedAtUtc datetime2(3) NULL,
        AccountStatus varchar(12) NOT NULL
            CONSTRAINT DF_Users_AccountStatus DEFAULT ('Active'),
        CreatedAtUtc datetime2(3) NOT NULL
            CONSTRAINT DF_Users_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
        UpdatedAtUtc datetime2(3) NOT NULL
            CONSTRAINT DF_Users_UpdatedAtUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_Users PRIMARY KEY (UserId),
        CONSTRAINT UQ_Users_Email UNIQUE (Email),
        CONSTRAINT CK_Users_UserId_NotBlank CHECK (LEN(LTRIM(RTRIM(UserId))) > 0),
        CONSTRAINT CK_Users_Email_NotBlank CHECK (LEN(LTRIM(RTRIM(Email))) > 3),
        CONSTRAINT CK_Users_AccountStatus CHECK (AccountStatus IN ('Active', 'Disabled'))
    );

    /* Authentication provider identifiers only. Passwords and tokens are never stored here. */
    CREATE TABLE dbo.UserIdentities
    (
        UserIdentityId bigint IDENTITY(1,1) NOT NULL,
        UserId nvarchar(128) NOT NULL,
        Provider varchar(64) NOT NULL,
        ProviderSubject nvarchar(255) NOT NULL,
        CreatedAtUtc datetime2(3) NOT NULL
            CONSTRAINT DF_UserIdentities_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_UserIdentities PRIMARY KEY (UserIdentityId),
        CONSTRAINT UQ_UserIdentities_ProviderSubject UNIQUE (Provider, ProviderSubject),
        CONSTRAINT FK_UserIdentities_Users FOREIGN KEY (UserId) REFERENCES dbo.Users (UserId),
        CONSTRAINT CK_UserIdentities_Provider_NotBlank CHECK (LEN(LTRIM(RTRIM(Provider))) > 0),
        CONSTRAINT CK_UserIdentities_Subject_NotBlank CHECK (LEN(LTRIM(RTRIM(ProviderSubject))) > 0)
    );
    CREATE INDEX IX_UserIdentities_UserId ON dbo.UserIdentities (UserId);

    CREATE TABLE dbo.UserProfiles
    (
        UserId nvarchar(128) NOT NULL,
        DisplayName nvarchar(100) NULL,
        FitnessGoal varchar(20) NULL,
        HeightCm decimal(5,2) NULL,
        WeightKg decimal(6,2) NULL,
        DailyFoodBudget decimal(10,2) NULL,
        BudgetCurrency char(3) NOT NULL
            CONSTRAINT DF_UserProfiles_BudgetCurrency DEFAULT ('INR'),
        TimeZoneId nvarchar(80) NOT NULL
            CONSTRAINT DF_UserProfiles_TimeZoneId DEFAULT (N'Asia/Kolkata'),
        CreatedAtUtc datetime2(3) NOT NULL
            CONSTRAINT DF_UserProfiles_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
        UpdatedAtUtc datetime2(3) NOT NULL
            CONSTRAINT DF_UserProfiles_UpdatedAtUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_UserProfiles PRIMARY KEY (UserId),
        CONSTRAINT FK_UserProfiles_Users FOREIGN KEY (UserId) REFERENCES dbo.Users (UserId),
        CONSTRAINT CK_UserProfiles_FitnessGoal CHECK (FitnessGoal IS NULL OR FitnessGoal IN ('GeneralFitness', 'BuildMuscle', 'LoseFat', 'Maintain')),
        CONSTRAINT CK_UserProfiles_HeightCm CHECK (HeightCm IS NULL OR (HeightCm > 0 AND HeightCm <= 300)),
        CONSTRAINT CK_UserProfiles_WeightKg CHECK (WeightKg IS NULL OR (WeightKg > 0 AND WeightKg <= 500)),
        CONSTRAINT CK_UserProfiles_Budget CHECK (DailyFoodBudget IS NULL OR DailyFoodBudget >= 0)
    );

    CREATE TABLE dbo.DietaryPreferences
    (
        PreferenceCode varchar(32) NOT NULL,
        PreferenceName nvarchar(80) NOT NULL,
        CONSTRAINT PK_DietaryPreferences PRIMARY KEY (PreferenceCode),
        CONSTRAINT UQ_DietaryPreferences_Name UNIQUE (PreferenceName)
    );

    CREATE TABLE dbo.UserDietaryPreferences
    (
        UserId nvarchar(128) NOT NULL,
        PreferenceCode varchar(32) NOT NULL,
        CONSTRAINT PK_UserDietaryPreferences PRIMARY KEY (UserId, PreferenceCode),
        CONSTRAINT FK_UserDietaryPreferences_Users FOREIGN KEY (UserId) REFERENCES dbo.Users (UserId),
        CONSTRAINT FK_UserDietaryPreferences_Preferences FOREIGN KEY (PreferenceCode) REFERENCES dbo.DietaryPreferences (PreferenceCode)
    );
    CREATE INDEX IX_UserDietaryPreferences_PreferenceCode ON dbo.UserDietaryPreferences (PreferenceCode, UserId);

    CREATE TABLE dbo.UserNutritionTargets
    (
        UserNutritionTargetId bigint IDENTITY(1,1) NOT NULL,
        UserId nvarchar(128) NOT NULL,
        EffectiveFrom date NOT NULL,
        CaloriesKcal decimal(9,2) NULL,
        ProteinGrams decimal(8,2) NULL,
        CarbohydrateGrams decimal(8,2) NULL,
        FatGrams decimal(8,2) NULL,
        WaterMillilitres int NULL,
        CreatedAtUtc datetime2(3) NOT NULL
            CONSTRAINT DF_UserNutritionTargets_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_UserNutritionTargets PRIMARY KEY (UserNutritionTargetId),
        CONSTRAINT UQ_UserNutritionTargets_User_Date UNIQUE (UserId, EffectiveFrom),
        CONSTRAINT FK_UserNutritionTargets_Users FOREIGN KEY (UserId) REFERENCES dbo.Users (UserId),
        CONSTRAINT CK_UserNutritionTargets_Calories CHECK (CaloriesKcal IS NULL OR CaloriesKcal > 0),
        CONSTRAINT CK_UserNutritionTargets_Protein CHECK (ProteinGrams IS NULL OR ProteinGrams > 0),
        CONSTRAINT CK_UserNutritionTargets_Carbs CHECK (CarbohydrateGrams IS NULL OR CarbohydrateGrams > 0),
        CONSTRAINT CK_UserNutritionTargets_Fat CHECK (FatGrams IS NULL OR FatGrams > 0),
        CONSTRAINT CK_UserNutritionTargets_Water CHECK (WaterMillilitres IS NULL OR WaterMillilitres > 0)
    );
    CREATE INDEX IX_UserNutritionTargets_User_EffectiveFrom ON dbo.UserNutritionTargets (UserId, EffectiveFrom DESC);

    CREATE TABLE dbo.FoodCategories
    (
        FoodCategoryId int IDENTITY(1,1) NOT NULL,
        CategoryCode varchar(32) NOT NULL,
        CategoryName nvarchar(80) NOT NULL,
        CONSTRAINT PK_FoodCategories PRIMARY KEY (FoodCategoryId),
        CONSTRAINT UQ_FoodCategories_Code UNIQUE (CategoryCode),
        CONSTRAINT UQ_FoodCategories_Name UNIQUE (CategoryName)
    );

    CREATE TABLE dbo.Foods
    (
        FoodId bigint IDENTITY(1,1) NOT NULL,
        FoodCategoryId int NOT NULL,
        FoodName nvarchar(160) NOT NULL,
        SearchName nvarchar(160) NOT NULL,
        IsActive bit NOT NULL CONSTRAINT DF_Foods_IsActive DEFAULT (1),
        CreatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_Foods_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
        UpdatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_Foods_UpdatedAtUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_Foods PRIMARY KEY (FoodId),
        CONSTRAINT UQ_Foods_FoodName UNIQUE (FoodName),
        CONSTRAINT FK_Foods_FoodCategories FOREIGN KEY (FoodCategoryId) REFERENCES dbo.FoodCategories (FoodCategoryId),
        CONSTRAINT CK_Foods_Name_NotBlank CHECK (LEN(LTRIM(RTRIM(FoodName))) > 0),
        CONSTRAINT CK_Foods_SearchName_NotBlank CHECK (LEN(LTRIM(RTRIM(SearchName))) > 0)
    );
    CREATE INDEX IX_Foods_SearchName_Active ON dbo.Foods (SearchName, FoodId) INCLUDE (FoodName, FoodCategoryId) WHERE IsActive = 1;
    CREATE INDEX IX_Foods_Category_Active ON dbo.Foods (FoodCategoryId, SearchName) WHERE IsActive = 1;

    CREATE TABLE dbo.FoodAliases
    (
        FoodAliasId bigint IDENTITY(1,1) NOT NULL,
        FoodId bigint NOT NULL,
        Alias nvarchar(160) NOT NULL,
        SearchName nvarchar(160) NOT NULL,
        LanguageCode varchar(16) NOT NULL,
        CONSTRAINT PK_FoodAliases PRIMARY KEY (FoodAliasId),
        CONSTRAINT UQ_FoodAliases_Language_SearchName UNIQUE (LanguageCode, SearchName),
        CONSTRAINT FK_FoodAliases_Foods FOREIGN KEY (FoodId) REFERENCES dbo.Foods (FoodId),
        CONSTRAINT CK_FoodAliases_Alias CHECK (LEN(LTRIM(RTRIM(Alias))) > 0),
        CONSTRAINT CK_FoodAliases_SearchName CHECK (LEN(LTRIM(RTRIM(SearchName))) > 0),
        CONSTRAINT CK_FoodAliases_Language CHECK (LEN(LTRIM(RTRIM(LanguageCode))) > 0)
    );
    CREATE INDEX IX_FoodAliases_FoodId ON dbo.FoodAliases (FoodId, LanguageCode);

    CREATE TABLE dbo.FoodServingConversions
    (
        FoodServingConversionId bigint IDENTITY(1,1) NOT NULL,
        FoodId bigint NOT NULL,
        ServingName nvarchar(80) NOT NULL,
        EquivalentAmount decimal(10,3) NOT NULL,
        EquivalentUnit varchar(24) NOT NULL,
        EvidenceStatus varchar(12) NOT NULL,
        SourceName nvarchar(160) NOT NULL,
        SourceUrl nvarchar(2048) NULL,
        VerifiedAtUtc datetime2(3) NULL,
        CONSTRAINT PK_FoodServingConversions PRIMARY KEY (FoodServingConversionId),
        CONSTRAINT UQ_FoodServingConversions_Food_Serving UNIQUE (FoodId, ServingName),
        CONSTRAINT FK_FoodServingConversions_Foods FOREIGN KEY (FoodId) REFERENCES dbo.Foods (FoodId),
        CONSTRAINT CK_FoodServingConversions_Name CHECK (LEN(LTRIM(RTRIM(ServingName))) > 0),
        CONSTRAINT CK_FoodServingConversions_Amount CHECK (EquivalentAmount > 0),
        CONSTRAINT CK_FoodServingConversions_Unit CHECK (LEN(LTRIM(RTRIM(EquivalentUnit))) > 0),
        CONSTRAINT CK_FoodServingConversions_Status CHECK (EvidenceStatus IN ('Verified', 'Estimated')),
        CONSTRAINT CK_FoodServingConversions_Source CHECK (LEN(LTRIM(RTRIM(SourceName))) > 0),
        CONSTRAINT CK_FoodServingConversions_VerifiedAt CHECK (EvidenceStatus <> 'Verified' OR VerifiedAtUtc IS NOT NULL)
    );
    CREATE INDEX IX_FoodServingConversions_FoodId ON dbo.FoodServingConversions (FoodId, ServingName)
        INCLUDE (EquivalentAmount, EquivalentUnit, EvidenceStatus);

    /* Nutrients are values for the explicitly stated reference quantity; NULL means unknown. */
    CREATE TABLE dbo.FoodNutrition
    (
        FoodId bigint NOT NULL,
        ReferenceAmount decimal(10,3) NOT NULL,
        ReferenceUnit varchar(24) NOT NULL,
        CaloriesKcal decimal(9,2) NULL,
        ProteinGrams decimal(8,2) NULL,
        CarbohydrateGrams decimal(8,2) NULL,
        FatGrams decimal(8,2) NULL,
        FibreGrams decimal(8,2) NULL,
        SodiumMilligrams decimal(9,2) NULL,
        EvidenceStatus varchar(12) NOT NULL,
        SourceName nvarchar(160) NOT NULL,
        SourceUrl nvarchar(2048) NULL,
        VerifiedAtUtc datetime2(3) NULL,
        UpdatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_FoodNutrition_UpdatedAtUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_FoodNutrition PRIMARY KEY (FoodId),
        CONSTRAINT FK_FoodNutrition_Foods FOREIGN KEY (FoodId) REFERENCES dbo.Foods (FoodId),
        CONSTRAINT CK_FoodNutrition_ReferenceAmount CHECK (ReferenceAmount > 0),
        CONSTRAINT CK_FoodNutrition_ReferenceUnit CHECK (LEN(LTRIM(RTRIM(ReferenceUnit))) > 0),
        CONSTRAINT CK_FoodNutrition_Status CHECK (EvidenceStatus IN ('Verified', 'Estimated')),
        CONSTRAINT CK_FoodNutrition_Source CHECK (LEN(LTRIM(RTRIM(SourceName))) > 0),
        CONSTRAINT CK_FoodNutrition_VerifiedAt CHECK (EvidenceStatus <> 'Verified' OR VerifiedAtUtc IS NOT NULL),
        CONSTRAINT CK_FoodNutrition_Calories CHECK (CaloriesKcal IS NULL OR CaloriesKcal >= 0),
        CONSTRAINT CK_FoodNutrition_Protein CHECK (ProteinGrams IS NULL OR ProteinGrams >= 0),
        CONSTRAINT CK_FoodNutrition_Carbs CHECK (CarbohydrateGrams IS NULL OR CarbohydrateGrams >= 0),
        CONSTRAINT CK_FoodNutrition_Fat CHECK (FatGrams IS NULL OR FatGrams >= 0),
        CONSTRAINT CK_FoodNutrition_Fibre CHECK (FibreGrams IS NULL OR FibreGrams >= 0),
        CONSTRAINT CK_FoodNutrition_Sodium CHECK (SodiumMilligrams IS NULL OR SodiumMilligrams >= 0)
    );

    CREATE TABLE dbo.FoodPrices
    (
        FoodPriceId bigint IDENTITY(1,1) NOT NULL,
        FoodId bigint NOT NULL,
        PriceAmount decimal(10,2) NOT NULL,
        CurrencyCode char(3) NOT NULL,
        QuantityAmount decimal(10,3) NOT NULL,
        QuantityUnit varchar(24) NOT NULL,
        EvidenceStatus varchar(12) NOT NULL,
        SourceName nvarchar(160) NOT NULL,
        SourceUrl nvarchar(2048) NULL,
        ObservedOn date NOT NULL,
        ExpiresOn date NULL,
        CreatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_FoodPrices_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_FoodPrices PRIMARY KEY (FoodPriceId),
        CONSTRAINT FK_FoodPrices_Foods FOREIGN KEY (FoodId) REFERENCES dbo.Foods (FoodId),
        CONSTRAINT CK_FoodPrices_Price CHECK (PriceAmount > 0),
        CONSTRAINT CK_FoodPrices_Quantity CHECK (QuantityAmount > 0),
        CONSTRAINT CK_FoodPrices_Unit CHECK (LEN(LTRIM(RTRIM(QuantityUnit))) > 0),
        CONSTRAINT CK_FoodPrices_Status CHECK (EvidenceStatus IN ('Verified', 'Estimated')),
        CONSTRAINT CK_FoodPrices_Source CHECK (LEN(LTRIM(RTRIM(SourceName))) > 0),
        CONSTRAINT CK_FoodPrices_Expiry CHECK (ExpiresOn IS NULL OR ExpiresOn >= ObservedOn)
    );
    CREATE INDEX IX_FoodPrices_Food_ObservedOn ON dbo.FoodPrices (FoodId, ObservedOn DESC) INCLUDE (PriceAmount, CurrencyCode, QuantityAmount, QuantityUnit, EvidenceStatus, ExpiresOn);

    CREATE TABLE dbo.Meals
    (
        MealId bigint IDENTITY(1,1) NOT NULL,
        UserId nvarchar(128) NOT NULL,
        MealDate date NOT NULL,
        MealType varchar(12) NOT NULL,
        Notes nvarchar(600) NULL,
        CreatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_Meals_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
        UpdatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_Meals_UpdatedAtUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_Meals PRIMARY KEY (MealId),
        CONSTRAINT UQ_Meals_MealId_UserId UNIQUE (MealId, UserId),
        CONSTRAINT FK_Meals_Users FOREIGN KEY (UserId) REFERENCES dbo.Users (UserId),
        CONSTRAINT CK_Meals_MealType CHECK (MealType IN ('Breakfast', 'Lunch', 'Dinner', 'Snack'))
    );
    CREATE INDEX IX_Meals_User_Date ON dbo.Meals (UserId, MealDate DESC, MealId DESC) INCLUDE (MealType, CreatedAtUtc);

    /* Confirmed values are snapshots so catalogue corrections do not rewrite logged history. */
    CREATE TABLE dbo.MealItems
    (
        MealItemId bigint IDENTITY(1,1) NOT NULL,
        MealId bigint NOT NULL,
        UserId nvarchar(128) NOT NULL,
        FoodId bigint NULL,
        FoodNameSnapshot nvarchar(160) NOT NULL,
        ServingAmount decimal(10,3) NOT NULL,
        ServingUnit varchar(24) NOT NULL,
        CaloriesKcal decimal(9,2) NULL,
        ProteinGrams decimal(8,2) NULL,
        CarbohydrateGrams decimal(8,2) NULL,
        FatGrams decimal(8,2) NULL,
        NutritionSourceSnapshot nvarchar(160) NULL,
        NutritionSourceUrlSnapshot nvarchar(2048) NULL,
        EvidenceStatus varchar(12) NOT NULL,
        CreatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_MealItems_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_MealItems PRIMARY KEY (MealItemId),
        CONSTRAINT FK_MealItems_Meals_User FOREIGN KEY (MealId, UserId) REFERENCES dbo.Meals (MealId, UserId),
        CONSTRAINT FK_MealItems_Foods FOREIGN KEY (FoodId) REFERENCES dbo.Foods (FoodId),
        CONSTRAINT CK_MealItems_Name_NotBlank CHECK (LEN(LTRIM(RTRIM(FoodNameSnapshot))) > 0),
        CONSTRAINT CK_MealItems_ServingAmount CHECK (ServingAmount > 0),
        CONSTRAINT CK_MealItems_ServingUnit CHECK (LEN(LTRIM(RTRIM(ServingUnit))) > 0),
        CONSTRAINT CK_MealItems_EvidenceStatus CHECK (EvidenceStatus IN ('Verified', 'Estimated', 'Incomplete')),
        CONSTRAINT CK_MealItems_VerifiedSource CHECK (EvidenceStatus <> 'Verified' OR NutritionSourceSnapshot IS NOT NULL),
        CONSTRAINT CK_MealItems_Calories CHECK (CaloriesKcal IS NULL OR CaloriesKcal >= 0),
        CONSTRAINT CK_MealItems_Protein CHECK (ProteinGrams IS NULL OR ProteinGrams >= 0),
        CONSTRAINT CK_MealItems_Carbs CHECK (CarbohydrateGrams IS NULL OR CarbohydrateGrams >= 0),
        CONSTRAINT CK_MealItems_Fat CHECK (FatGrams IS NULL OR FatGrams >= 0)
    );
    CREATE INDEX IX_MealItems_Meal_User ON dbo.MealItems (MealId, UserId) INCLUDE (FoodId, ServingAmount, CaloriesKcal, ProteinGrams, CarbohydrateGrams, FatGrams, EvidenceStatus);
    CREATE INDEX IX_MealItems_User_Food ON dbo.MealItems (UserId, FoodId) WHERE FoodId IS NOT NULL;

    CREATE TABLE dbo.Equipment
    (
        EquipmentId int IDENTITY(1,1) NOT NULL,
        EquipmentCode varchar(32) NOT NULL,
        EquipmentName nvarchar(80) NOT NULL,
        CONSTRAINT PK_Equipment PRIMARY KEY (EquipmentId),
        CONSTRAINT UQ_Equipment_Code UNIQUE (EquipmentCode),
        CONSTRAINT UQ_Equipment_Name UNIQUE (EquipmentName)
    );

    CREATE TABLE dbo.UserEquipment
    (
        UserId nvarchar(128) NOT NULL,
        EquipmentId int NOT NULL,
        CONSTRAINT PK_UserEquipment PRIMARY KEY (UserId, EquipmentId),
        CONSTRAINT FK_UserEquipment_Users FOREIGN KEY (UserId) REFERENCES dbo.Users (UserId),
        CONSTRAINT FK_UserEquipment_Equipment FOREIGN KEY (EquipmentId) REFERENCES dbo.Equipment (EquipmentId)
    );
    CREATE INDEX IX_UserEquipment_Equipment ON dbo.UserEquipment (EquipmentId, UserId);

    CREATE TABLE dbo.Exercises
    (
        ExerciseId bigint IDENTITY(1,1) NOT NULL,
        ExerciseName nvarchar(160) NOT NULL,
        PrimaryMuscleGroup nvarchar(80) NOT NULL,
        Instructions nvarchar(1200) NULL,
        IsActive bit NOT NULL CONSTRAINT DF_Exercises_IsActive DEFAULT (1),
        CONSTRAINT PK_Exercises PRIMARY KEY (ExerciseId),
        CONSTRAINT UQ_Exercises_Name UNIQUE (ExerciseName),
        CONSTRAINT CK_Exercises_Name_NotBlank CHECK (LEN(LTRIM(RTRIM(ExerciseName))) > 0),
        CONSTRAINT CK_Exercises_Muscle_NotBlank CHECK (LEN(LTRIM(RTRIM(PrimaryMuscleGroup))) > 0)
    );
    CREATE INDEX IX_Exercises_Muscle_Active ON dbo.Exercises (PrimaryMuscleGroup, ExerciseName) WHERE IsActive = 1;

    CREATE TABLE dbo.ExerciseEquipment
    (
        ExerciseId bigint NOT NULL,
        EquipmentId int NOT NULL,
        CONSTRAINT PK_ExerciseEquipment PRIMARY KEY (ExerciseId, EquipmentId),
        CONSTRAINT FK_ExerciseEquipment_Exercises FOREIGN KEY (ExerciseId) REFERENCES dbo.Exercises (ExerciseId),
        CONSTRAINT FK_ExerciseEquipment_Equipment FOREIGN KEY (EquipmentId) REFERENCES dbo.Equipment (EquipmentId)
    );
    CREATE INDEX IX_ExerciseEquipment_Equipment ON dbo.ExerciseEquipment (EquipmentId, ExerciseId);

    CREATE TABLE dbo.WorkoutPlans
    (
        WorkoutPlanId bigint IDENTITY(1,1) NOT NULL,
        UserId nvarchar(128) NOT NULL,
        PlanName nvarchar(120) NOT NULL,
        DaysPerWeek tinyint NOT NULL,
        ExperienceLevel varchar(12) NOT NULL,
        IsActive bit NOT NULL CONSTRAINT DF_WorkoutPlans_IsActive DEFAULT (1),
        CreatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_WorkoutPlans_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
        UpdatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_WorkoutPlans_UpdatedAtUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_WorkoutPlans PRIMARY KEY (WorkoutPlanId),
        CONSTRAINT UQ_WorkoutPlans_Id_User UNIQUE (WorkoutPlanId, UserId),
        CONSTRAINT FK_WorkoutPlans_Users FOREIGN KEY (UserId) REFERENCES dbo.Users (UserId),
        CONSTRAINT CK_WorkoutPlans_Name_NotBlank CHECK (LEN(LTRIM(RTRIM(PlanName))) > 0),
        CONSTRAINT CK_WorkoutPlans_Days CHECK (DaysPerWeek BETWEEN 3 AND 6),
        CONSTRAINT CK_WorkoutPlans_Experience CHECK (ExperienceLevel IN ('Beginner', 'Intermediate', 'Advanced'))
    );
    CREATE INDEX IX_WorkoutPlans_User_Active ON dbo.WorkoutPlans (UserId, IsActive, UpdatedAtUtc DESC);

    CREATE TABLE dbo.WorkoutPlanDays
    (
        WorkoutPlanDayId bigint IDENTITY(1,1) NOT NULL,
        WorkoutPlanId bigint NOT NULL,
        UserId nvarchar(128) NOT NULL,
        PlanDayNumber tinyint NOT NULL,
        DayName nvarchar(80) NOT NULL,
        CONSTRAINT PK_WorkoutPlanDays PRIMARY KEY (WorkoutPlanDayId),
        CONSTRAINT UQ_WorkoutPlanDays_Id_User UNIQUE (WorkoutPlanDayId, UserId),
        CONSTRAINT UQ_WorkoutPlanDays_Plan_Day UNIQUE (WorkoutPlanId, PlanDayNumber),
        CONSTRAINT FK_WorkoutPlanDays_Plan_User FOREIGN KEY (WorkoutPlanId, UserId) REFERENCES dbo.WorkoutPlans (WorkoutPlanId, UserId),
        CONSTRAINT CK_WorkoutPlanDays_DayNumber CHECK (PlanDayNumber BETWEEN 1 AND 6),
        CONSTRAINT CK_WorkoutPlanDays_Name CHECK (LEN(LTRIM(RTRIM(DayName))) > 0)
    );
    CREATE INDEX IX_WorkoutPlanDays_Plan_User ON dbo.WorkoutPlanDays (WorkoutPlanId, UserId, PlanDayNumber);

    CREATE TABLE dbo.WorkoutPlanExercises
    (
        WorkoutPlanExerciseId bigint IDENTITY(1,1) NOT NULL,
        WorkoutPlanDayId bigint NOT NULL,
        UserId nvarchar(128) NOT NULL,
        ExerciseId bigint NOT NULL,
        Position smallint NOT NULL,
        Sets tinyint NOT NULL,
        RepsMinimum smallint NOT NULL,
        RepsMaximum smallint NOT NULL,
        RestSeconds smallint NOT NULL,
        CONSTRAINT PK_WorkoutPlanExercises PRIMARY KEY (WorkoutPlanExerciseId),
        CONSTRAINT UQ_WorkoutPlanExercises_Day_Position UNIQUE (WorkoutPlanDayId, Position),
        CONSTRAINT FK_WorkoutPlanExercises_Day_User FOREIGN KEY (WorkoutPlanDayId, UserId) REFERENCES dbo.WorkoutPlanDays (WorkoutPlanDayId, UserId),
        CONSTRAINT FK_WorkoutPlanExercises_Exercises FOREIGN KEY (ExerciseId) REFERENCES dbo.Exercises (ExerciseId),
        CONSTRAINT CK_WorkoutPlanExercises_Position CHECK (Position > 0),
        CONSTRAINT CK_WorkoutPlanExercises_Sets CHECK (Sets BETWEEN 1 AND 20),
        CONSTRAINT CK_WorkoutPlanExercises_Reps CHECK (RepsMinimum > 0 AND RepsMaximum >= RepsMinimum AND RepsMaximum <= 1000),
        CONSTRAINT CK_WorkoutPlanExercises_Rest CHECK (RestSeconds BETWEEN 0 AND 3600)
    );
    CREATE INDEX IX_WorkoutPlanExercises_Day_User ON dbo.WorkoutPlanExercises (WorkoutPlanDayId, UserId, Position) INCLUDE (ExerciseId, Sets, RepsMinimum, RepsMaximum, RestSeconds);

    CREATE TABLE dbo.WorkoutSessions
    (
        WorkoutSessionId bigint IDENTITY(1,1) NOT NULL,
        UserId nvarchar(128) NOT NULL,
        WorkoutPlanId bigint NULL,
        SessionDate date NOT NULL,
        SessionStatus varchar(10) NOT NULL CONSTRAINT DF_WorkoutSessions_Status DEFAULT ('Planned'),
        StartedAtUtc datetime2(3) NULL,
        CompletedAtUtc datetime2(3) NULL,
        Notes nvarchar(600) NULL,
        CreatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_WorkoutSessions_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
        UpdatedAtUtc datetime2(3) NOT NULL CONSTRAINT DF_WorkoutSessions_UpdatedAtUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_WorkoutSessions PRIMARY KEY (WorkoutSessionId),
        CONSTRAINT UQ_WorkoutSessions_Id_User UNIQUE (WorkoutSessionId, UserId),
        CONSTRAINT FK_WorkoutSessions_Users FOREIGN KEY (UserId) REFERENCES dbo.Users (UserId),
        CONSTRAINT FK_WorkoutSessions_Plan_User FOREIGN KEY (WorkoutPlanId, UserId) REFERENCES dbo.WorkoutPlans (WorkoutPlanId, UserId),
        CONSTRAINT CK_WorkoutSessions_Status CHECK (SessionStatus IN ('Planned', 'Completed', 'Skipped')),
        CONSTRAINT CK_WorkoutSessions_Completion CHECK ((SessionStatus = 'Completed' AND CompletedAtUtc IS NOT NULL) OR (SessionStatus <> 'Completed' AND CompletedAtUtc IS NULL)),
        CONSTRAINT CK_WorkoutSessions_TimeOrder CHECK (StartedAtUtc IS NULL OR CompletedAtUtc IS NULL OR CompletedAtUtc >= StartedAtUtc)
    );
    CREATE INDEX IX_WorkoutSessions_User_Date ON dbo.WorkoutSessions (UserId, SessionDate DESC, WorkoutSessionId DESC) INCLUDE (WorkoutPlanId, SessionStatus, CompletedAtUtc);

    CREATE TABLE dbo.WorkoutLogs
    (
        WorkoutLogId bigint IDENTITY(1,1) NOT NULL,
        WorkoutSessionId bigint NOT NULL,
        UserId nvarchar(128) NOT NULL,
        ExerciseId bigint NULL,
        ExerciseNameSnapshot nvarchar(160) NOT NULL,
        Position smallint NOT NULL,
        Notes nvarchar(400) NULL,
        CONSTRAINT PK_WorkoutLogs PRIMARY KEY (WorkoutLogId),
        CONSTRAINT UQ_WorkoutLogs_Id_User UNIQUE (WorkoutLogId, UserId),
        CONSTRAINT UQ_WorkoutLogs_Session_Position UNIQUE (WorkoutSessionId, Position),
        CONSTRAINT FK_WorkoutLogs_Session_User FOREIGN KEY (WorkoutSessionId, UserId) REFERENCES dbo.WorkoutSessions (WorkoutSessionId, UserId),
        CONSTRAINT FK_WorkoutLogs_Exercises FOREIGN KEY (ExerciseId) REFERENCES dbo.Exercises (ExerciseId),
        CONSTRAINT CK_WorkoutLogs_Name CHECK (LEN(LTRIM(RTRIM(ExerciseNameSnapshot))) > 0),
        CONSTRAINT CK_WorkoutLogs_Position CHECK (Position > 0)
    );
    CREATE INDEX IX_WorkoutLogs_Session_User ON dbo.WorkoutLogs (WorkoutSessionId, UserId, Position) INCLUDE (ExerciseId);

    CREATE TABLE dbo.WorkoutSets
    (
        WorkoutSetId bigint IDENTITY(1,1) NOT NULL,
        WorkoutLogId bigint NOT NULL,
        UserId nvarchar(128) NOT NULL,
        SetNumber tinyint NOT NULL,
        Repetitions smallint NOT NULL,
        WeightKg decimal(7,2) NULL,
        Notes nvarchar(300) NULL,
        CONSTRAINT PK_WorkoutSets PRIMARY KEY (WorkoutSetId),
        CONSTRAINT UQ_WorkoutSets_Log_Set UNIQUE (WorkoutLogId, SetNumber),
        CONSTRAINT FK_WorkoutSets_Log_User FOREIGN KEY (WorkoutLogId, UserId) REFERENCES dbo.WorkoutLogs (WorkoutLogId, UserId),
        CONSTRAINT CK_WorkoutSets_SetNumber CHECK (SetNumber BETWEEN 1 AND 50),
        CONSTRAINT CK_WorkoutSets_Repetitions CHECK (Repetitions BETWEEN 1 AND 1000),
        CONSTRAINT CK_WorkoutSets_Weight CHECK (WeightKg IS NULL OR WeightKg >= 0)
    );
    CREATE INDEX IX_WorkoutSets_Log_User ON dbo.WorkoutSets (WorkoutLogId, UserId, SetNumber) INCLUDE (Repetitions, WeightKg);

    INSERT INTO dbo.SchemaMigrations (MigrationId) VALUES (N'001_initial_schema');

    COMMIT TRANSACTION;
    PRINT N'FitAI migration 001 applied successfully.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
