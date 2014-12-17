class CampaignsController < ApplicationController
  layout 'campaign', except: [:edit, :goals_wizard, :index, :public_page]
  before_filter :authenticate_user!, except: [:public_page, :share]
  before_filter :assign_campaign_variables, except: [:index, :setup, :create, :destroy]

  def index
    @campaign = Campaign.new
    @campaigns = current_user.campaigns.sort_by(&:status)
  end

  def new
    @campaign = Campaign.find(params[:id])
  end

  def create
    @campaign = current_user.campaigns.find_or_create_by(id: params[:campaign][:id])
    @campaign.update_attributes(campaign_params)
    if @campaign.save
      render js: "window.location = '#{edit_campaign_path(@campaign)}'"
    else
      render json: { errors: @campaign.errors.full_messages }.to_json, status: 422
    end
  end

  def show
    redirect_to action: get_latest_state, id: @campaign.id
  end

  def next
    permission = campaign_can_advance?(params[:refer_action])

    if permission == true
      redirect_to action: get_next_state(params[:refer_action]), id: @campaign.id
    else
      render json: { errors: [permission] }.to_json, status: 401
    end
  end

  def goals_wizard
  end

  def edit
  end

  def update
    @campaign = Campaign.find(params[:id])
    @campaign.update_attributes(campaign_params)
    if @campaign.survey
      @campaign.survey.update_attribute(:title, @campaign.title)
    end
    
    if @campaign.organizers
      redirect_to test_campaign_path(@campaign)
    else
      redirect_to campaign_survey_path(@campaign)
    end
  end

  def survey
  end

  def profile
  end

  def edit_profile
  end

  def test
    if @campaign.status == 'draft'
      @survey.activate('test')
    end
  end

  #Post survey definition to aggregator
  def activate
    if @survey.activate(params[:status])['status'] == 'success'
      @campaign.update_attribute(:status, params[:status])
      flash.now[:notice] = t('.upload_success')
      @campaign.update_attribute(:start_date, Time.now)

      if params[:status] == 'test'
        redirect_to test_campaign_path(@campaign)
      elsif params[:status] == 'active'
        redirect_to monitor_campaign_path(@campaign)
      end
    else
      flash.now[:notice] = t('.upload_error')
      render :test
    end
  end

  def monitor
  end

  def share
  end

  def close
    if @survey.close['status'] == 'success'
      @campaign.update_attribute(:status, 'closed')
      redirect_to share_campaign_path(@campaign)
    end
  end

  def clone
    campaign = Campaign.find(params[:id])
    campaign_clone = campaign.clone
    title = campaign.title + " #{t('campaigns.status.copy')}"
    campaign_clone.update_attributes(
      title: title + " #{Campaign.where(title: title).count if Campaign.where(title: title).count > 0}",
      organizers: nil,
      status: 'draft'
    )
    campaign.save

    if campaign.survey
      campaign_clone.survey = campaign.survey.clone
      campaign_clone.survey.update_attribute(:title, campaign_clone.title)
    end

    current_user.campaigns << campaign_clone
    redirect_to edit_campaign_path(campaign_clone)
  end

  def destroy
    Campaign.delete(params[:id])
    redirect_to campaigns_path
  end


  private

  def get_latest_state
    if @campaign.status == 'closed'
      "share"
    elsif @campaign.status == 'active'
      "monitor"
    elsif @campaign.status == 'test'
      "test"
    elsif @campaign.survey
      "survey"
    else
      "edit"
    end
  end

  def get_next_state(current_action)
    states = [
      "edit", 
      "survey",
      "edit_profile",
      "test",
      "monitor",
      "share"
    ]

    states[states.index(current_action) + 1]
  end

  def campaign_can_advance?(current_action)
    case current_action
    when "edit"
      if @campaign.validate_goals
        true
      else
        t("defaults.validations.please_define_goals")
      end
    when "survey"
      if @survey && @survey.inputs.length > 0
        true
      else
        t("defaults.validations.please_create_survey")
      end
    when "edit_profile"
      if @campaign.organizers && @campaign.description
        true
      else
        t("defaults.validations.please_complete_profile")
      end
    when "test"
      if @campaign.status == 'active'
        true
      else
        t("defaults.validations.launch_campaign")
      end
    when "monitor"
      if @campaign.status == 'closed'
        true
      else
        t("defaults.validations.close_campaign")
      end
    end
  end

  def assign_campaign_variables
    @campaign = Campaign.includes(survey: :inputs).find(params[:id])
    @survey = @campaign.survey
    @can_advance = campaign_can_advance?(params[:action])
  end

  def campaign_params
    params.require(:campaign).permit(:title, :description, :goal, :theme, :data_collectors, :submissions_target, :audience, :organizers)
  end

end
