module AccountableResource
  extend ActiveSupport::Concern

  included do
    include ScrollFocusable, Periodable

    before_action :set_account, only: [ :show, :edit, :update, :destroy ]
    before_action :set_link_options, only: :new
  end

  class_methods do
    def permitted_accountable_attributes(*attrs)
      @permitted_accountable_attributes = attrs if attrs.any?
      @permitted_accountable_attributes ||= [ :id ]
    end
  end

  def new
    @account = Current.family.accounts.build(
      currency: Current.family.currency,
      accountable: accountable_type.new
    )
  end

  def show
    @chart_view = params[:chart_view] || "balance"
    @q = params.fetch(:q, {}).permit(:search)
    entries = @account.entries.search(@q).reverse_chronological

    set_focused_record(entries, params[:focused_record_id])

    @pagy, @entries = pagy(entries, limit: params[:per_page] || "10", params: ->(params) { params.except(:focused_record_id) })
  end

  def edit
  end

  def create
    @account = Current.family.accounts.create_and_sync(account_params.except(:return_to))
    @account.lock_saved_attributes!

    redirect_to account_params[:return_to].presence || @account, notice: t("accounts.create.success", type: accountable_type.name.underscore.humanize)
  end

  def update
    @account.update_with_sync!(account_params.except(:return_to))
    @account.lock_saved_attributes!

    redirect_back_or_to @account, notice: t("accounts.update.success", type: accountable_type.name.underscore.humanize)
  end

  def destroy
    if @account.linked?
      redirect_to account_path(@account), alert: "Cannot delete a linked account"
    else
      @account.destroy_later
      redirect_to accounts_path, notice: t("accounts.destroy.success", type: accountable_type.name.underscore.humanize)
    end
  end

  private
    def set_link_options
      @show_us_link = Current.family.can_connect_plaid_us?
      @show_eu_link = Current.family.can_connect_plaid_eu?
    end

    def accountable_type
      controller_name.classify.constantize
    end

    def set_account
      @account = Current.family.accounts.find(params[:id])
    end

    def account_params
      params.require(:account).permit(
        :name, :is_active, :balance, :subtype, :currency, :accountable_type, :return_to,
        accountable_attributes: self.class.permitted_accountable_attributes
      )
    end
end
