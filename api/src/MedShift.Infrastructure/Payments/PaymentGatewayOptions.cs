namespace MedShift.Infrastructure.Payments;

public class PaymentGatewayOptions
{
    public const string SectionName = "PaymentGateway";

    /// <summary>Simulated | GbPrimePay</summary>
    public string Provider { get; set; } = "Simulated";

    public GbPrimePayOptions GbPrimePay { get; set; } = new();

    public bool UseGbPrimePay =>
        string.Equals(Provider, "GbPrimePay", StringComparison.OrdinalIgnoreCase)
        && !string.IsNullOrWhiteSpace(GbPrimePay.Token);
}

public class GbPrimePayOptions
{
    public string BaseUrl { get; set; } = "https://api.globalprimepay.com";
    public string Token { get; set; } = "";
    public string SecretKey { get; set; } = "";
    public string PublicKey { get; set; } = "";
    /// <summary>Public API base used to build backgroundUrl for webhooks (e.g. https://xxx.ngrok.io).</summary>
    public string WebhookPublicBaseUrl { get; set; } = "";
}
