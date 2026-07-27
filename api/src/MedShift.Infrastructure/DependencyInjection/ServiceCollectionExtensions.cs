using MedShift.Application.Interfaces;
using MedShift.Infrastructure.Auth;
using MedShift.Infrastructure.Email;
using MedShift.Infrastructure.Notifications;
using MedShift.Infrastructure.Payments;
using MedShift.Infrastructure.Persistence;
using MedShift.Infrastructure.Services;
using MedShift.Infrastructure.Storage;
using MedShift.Domain.Entities;
using MedShift.Domain.Enums;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Text;

namespace MedShift.Infrastructure.DependencyInjection;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddMedShiftInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<JwtSettings>(configuration.GetSection(JwtSettings.SectionName));
        services.Configure<FirebaseOptions>(configuration.GetSection(FirebaseOptions.SectionName));
        services.Configure<PaymentGatewayOptions>(configuration.GetSection(PaymentGatewayOptions.SectionName));
        services.Configure<EmailSettings>(configuration.GetSection(EmailSettings.SectionName));

        services.AddDbContext<MedShiftDbContext>(options =>
        {
            var cs = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection missing");
            var provider = configuration["Database:Provider"] ?? "SqlServer";
            if (string.Equals(provider, "Postgres", StringComparison.OrdinalIgnoreCase) ||
                string.Equals(provider, "PostgreSQL", StringComparison.OrdinalIgnoreCase))
            {
                // Free-tier / ARM (Oracle Ampere): SQL Server images are amd64-only.
                options.UseNpgsql(cs);
            }
            else
            {
                options.UseSqlServer(cs);
            }
        });

        var jwt = configuration.GetSection(JwtSettings.SectionName).Get<JwtSettings>()
            ?? throw new InvalidOperationException("Jwt settings missing");

        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                options.MapInboundClaims = false;
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidateAudience = true,
                    ValidateLifetime = true,
                    ValidateIssuerSigningKey = true,
                    ValidIssuer = jwt.Issuer,
                    ValidAudience = jwt.Audience,
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key)),
                    NameClaimType = JwtRegisteredClaimNames.Sub,
                    RoleClaimType = "role"
                };
            });

        services.AddAuthorization();
        services.AddHttpClient("gbprimepay");
        services.AddScoped<IFcmSender, FcmSender>();
        services.AddScoped<INotificationPublisher, NotificationPublisher>();
        services.AddScoped<IEmailSender, SmtpEmailSender>();

        var paymentOpts = configuration.GetSection(PaymentGatewayOptions.SectionName).Get<PaymentGatewayOptions>()
            ?? new PaymentGatewayOptions();
        if (paymentOpts.UseGbPrimePay)
            services.AddScoped<IPaymentGateway, GbPrimePayGateway>();
        else
            services.AddScoped<IPaymentGateway, SimulatedPaymentGateway>();

        services.AddScoped<IFileStorage, LocalFileStorage>();
        services.AddScoped<JobEscrowService>();
        services.AddScoped<IPasswordHasher, BcryptPasswordHasher>();
        services.AddScoped<IJwtTokenService, JwtTokenService>();
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IStaffService, StaffService>();
        services.AddScoped<IClinicService, ClinicService>();
        services.AddScoped<IAdminService, AdminService>();

        return services;
    }

    public static async Task SeedAsync(this IServiceProvider services)
    {
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<MedShiftDbContext>();
        var hasher = scope.ServiceProvider.GetRequiredService<IPasswordHasher>();
        var config = scope.ServiceProvider.GetRequiredService<IConfiguration>();

        var provider = config["Database:Provider"] ?? "SqlServer";
        var usePostgres = string.Equals(provider, "Postgres", StringComparison.OrdinalIgnoreCase)
            || string.Equals(provider, "PostgreSQL", StringComparison.OrdinalIgnoreCase);

        if (usePostgres)
        {
            // SQL Server migrations are not portable to Postgres (nvarchar/uniqueidentifier/etc).
            // Free Oracle ARM deploy uses EnsureCreated from the current model.
            // Schema changes on Postgres: recreate volume (`docker compose down -v`) or add a Postgres migration set later.
            await db.Database.EnsureCreatedAsync();
        }
        else
        {
            await db.Database.MigrateAsync();
        }

        if (!await db.Users.AnyAsync(u => u.Role == UserRole.Admin))
        {
            db.Users.Add(new User
            {
                Email = "admin@medshift.local",
                PasswordHash = hasher.Hash("Admin@12345"),
                Role = UserRole.Admin
            });
        }

        if (!await db.SystemSettings.AnyAsync())
        {
            db.SystemSettings.AddRange(
                new SystemSetting { Key = "cancellation_fee_24h", Value = "50", Description = "THB penalty within 24-48h" },
                new SystemSetting { Key = "cancellation_fee_under_24h", Value = "100", Description = "THB penalty under 24h" },
                new SystemSetting { Key = "max_waitlist_size", Value = "10", Description = "Max waitlist per job" },
                new SystemSetting { Key = "hourly_rate_min", Value = "200" },
                new SystemSetting { Key = "hourly_rate_max", Value = "1000" },
                new SystemSetting { Key = "platform_fee_percent", Value = "10", Description = "Platform fee % charged on top of staff pay at job post" });
        }
        else if (!await db.SystemSettings.AnyAsync(s => s.Key == "platform_fee_percent"))
        {
            db.SystemSettings.Add(new SystemSetting
            {
                Key = "platform_fee_percent",
                Value = "10",
                Description = "Platform fee % charged on top of staff pay at job post"
            });
        }

        if (!await db.CheckInRequirements.AnyAsync(r => r.OrganizationId == null && r.JobId == null))
        {
            db.CheckInRequirements.AddRange(
                new CheckInRequirement
                {
                    StepNumber = 1,
                    TitleTh = "ข้อกำหนดทั่วไป",
                    TitleEn = "General requirements",
                    ContentTh = "กรุณาแต่งกายสุภาพและตรงต่อเวลา",
                    ContentEn = "Please dress professionally and arrive on time.",
                    Type = "general"
                },
                new CheckInRequirement
                {
                    StepNumber = 2,
                    TitleTh = "ความลับผู้ป่วย",
                    TitleEn = "Patient confidentiality",
                    ContentTh = "ต้องรักษาความลับของผู้ป่วยอย่างเคร่งครัด",
                    ContentEn = "Patient confidentiality must be strictly maintained.",
                    Type = "privacy"
                });
        }

        if (!await db.Announcements.AnyAsync())
        {
            db.Announcements.Add(new Announcement
            {
                TitleTh = "ยินดีต้อนรับสู่ MedShift",
                TitleEn = "Welcome to MedShift",
                MessageTh = "แพลตฟอร์มรับงาน part-time สำหรับบุคลากรทางการแพทย์",
                MessageEn = "Part-time marketplace for medical professionals",
                Type = "info"
            });
        }

        await db.SaveChangesAsync();
    }
}
