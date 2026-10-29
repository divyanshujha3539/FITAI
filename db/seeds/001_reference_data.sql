/*
  FitAI reference data seed. Safe to rerun; does not update or delete existing rows.
  Catalogue foods and their nutrition/prices are intentionally not fabricated here.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO dbo.FoodCategories (CategoryCode, CategoryName)
    SELECT seed.CategoryCode, seed.CategoryName
    FROM (VALUES
        ('cereal', N'Cereals and grains'),
        ('legume', N'Pulses and legumes'),
        ('dairy', N'Dairy and alternatives'),
        ('egg', N'Eggs'),
        ('meat_fish', N'Meat and fish'),
        ('vegetable', N'Vegetables'),
        ('fruit', N'Fruits'),
        ('prepared_meal', N'Prepared meals'),
        ('snack', N'Snacks'),
        ('beverage', N'Beverages'),
        ('other', N'Other foods')
    ) AS seed (CategoryCode, CategoryName)
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.FoodCategories AS existing
        WHERE existing.CategoryCode = seed.CategoryCode
    );

    INSERT INTO dbo.DietaryPreferences (PreferenceCode, PreferenceName)
    SELECT seed.PreferenceCode, seed.PreferenceName
    FROM (VALUES
        ('vegetarian', N'Vegetarian'),
        ('vegan', N'Vegan'),
        ('eggetarian', N'Eggetarian'),
        ('jain', N'Jain'),
        ('halal', N'Halal'),
        ('gluten_free', N'Gluten-free'),
        ('lactose_free', N'Lactose-free')
    ) AS seed (PreferenceCode, PreferenceName)
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.DietaryPreferences AS existing
        WHERE existing.PreferenceCode = seed.PreferenceCode
    );

    INSERT INTO dbo.Equipment (EquipmentCode, EquipmentName)
    SELECT seed.EquipmentCode, seed.EquipmentName
    FROM (VALUES
        ('bodyweight', N'Bodyweight only'),
        ('dumbbell', N'Dumbbells'),
        ('barbell', N'Barbell'),
        ('resistance_band', N'Resistance bands'),
        ('pullup_bar', N'Pull-up bar'),
        ('cable_machine', N'Cable machine'),
        ('exercise_machine', N'Exercise machines')
    ) AS seed (EquipmentCode, EquipmentName)
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.Equipment AS existing
        WHERE existing.EquipmentCode = seed.EquipmentCode
    );

    COMMIT TRANSACTION;
    PRINT N'FitAI reference data seed completed.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
