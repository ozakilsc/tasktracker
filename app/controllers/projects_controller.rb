class ProjectsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :api_authentication!, only: [ :index, :show, :create, :update ]
  before_filter :set_viewable_project, only: [ :show, :colorpicker, :visible, :favorite, :settings ]
  before_filter :set_editable_project, only: [ :edit, :update, :destroy, :bulk, :reassign ]
  before_action :redirect_without_project, only: [ :show, :colorpicker, :visible, :favorite, :settings, :edit, :update, :destroy, :bulk, :reassign ]

  def bulk
  end

  def reassign
    original_user = User.with_project(@project.id, [true]).find_by_id(params[:from_user_id])       # Editors only
    reassign_to_user = User.with_project(@project.id, [true]).find_by_id(params[:to_user_id])      # Editors only
    params[:sticky_status] = 'not_completed' unless ['not_completed', 'completed', 'all'].include?(params[:sticky_status])

    respond_to do |format|
      if original_user and reassign_to_user
        sticky_scope = Sticky.where(project_id: @project.id, owner_id: original_user.id)
        if params[:sticky_status] == 'completed'
          sticky_scope = sticky_scope.where(completed: true)
        elsif params[:sticky_status] == 'not_completed'
          sticky_scope = sticky_scope.where(completed: false)
        end
        @sticky_count = sticky_scope.count
        sticky_scope.update_all(owner_id: reassign_to_user.id)
        format.html { redirect_to @project, notice: "#{@sticky_count} #{@sticky_count == 1 ? 'Sticky' : 'Stickies'} successfully reassigned." }
        format.js # reassign.js.erb
      else
        format.html do
          flash[:error] = 'Please select the original owner and new owner of the stickies.'
          render 'bulk'
        end
        format. js # reassign.js.erb
      end
    end
  end

  def colorpicker
    current_user.colors["project_#{@project.id}"] = params[:color]
    current_user.update_attributes colors: current_user.colors
    render nothing: true
  end

  def visible
    hidden_project_ids = current_user.hidden_project_ids
    if params[:visible] == '1'
      hidden_project_ids.delete(@project.id)
    else
      hidden_project_ids << @project.id
    end
    current_user.update_attributes hidden_project_ids: hidden_project_ids
  end

  def favorite
    project_favorite = @project.project_favorites.where( user_id: current_user.id ).first_or_create
    project_favorite.update_attributes favorite: (params[:favorite] == '1')
  end

  def selection
    @sticky = Sticky.new(params.require(:sticky).permit(:board_id, :owner_id, { :tag_ids => [] }))
    @project = current_user.all_projects.find_by_id(params[:sticky][:project_id])
    @project_id = @project.id if @project
  end

  # GET /projects
  # GET /projects.json
  def index
    current_user.update_column :projects_per_page, params[:projects_per_page].to_i if params[:projects_per_page].to_i >= 5 and params[:projects_per_page].to_i <= 200
    @order = scrub_order(Project, params[:order], 'projects.name')
    @projects = current_user.all_viewable_projects.search(params[:search]).by_favorite(current_user.id).order("(favorite IS NULL or favorite = 'f') ASC, " + @order).page(params[:page]).per(params[:format] == 'json' ? 50 : current_user.projects_per_page)
  end

  # GET /projects/1/settings
  def settings
  end

  # GET /projects/1
  # GET /projects/1.json
  def show
    params[:status] ||= ['planned','completed']
    @template = @project.templates.find_by_id(params[:template_id])

    unless @template
      @board = @project.boards.find_by_name(params[:board])
      params[:board_id] = @board ? @board.id : (params[:board_id] || 0)
      @board = @project.boards.find_by_id(params[:board_id]) unless @board
    end
  end

  # GET /projects/new
  def new
    @project = current_user.projects.new
  end

  # GET /projects/1/edit
  def edit
  end

  # POST /projects
  # POST /projects.json
  def create
    @project = current_user.projects.new(project_params)

    respond_to do |format|
      if @project.save
        format.html { redirect_to(@project, notice: 'Project was successfully created.') }
        format.js
        format.json { render action: 'show', status: :created, location: @project }
      else
        format.html { render 'new' }
        format.js { render 'new' }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /projects/1
  # PUT /projects/1.json
  def update
    respond_to do |format|
      if @project.update(project_params)
        format.html { redirect_to @project, notice: 'Project was successfully updated.' }
        format.json { render action: 'show', location: @project }
      else
        format.html { render action: 'edit' }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/1
  # DELETE /projects/1.json
  def destroy
    @project.destroy

    respond_to do |format|
      format.html { redirect_to projects_path }
      format.json { head :no_content }
    end
  end

  private

    def set_viewable_project
      super(:id)
    end

    # Overwriting application_controller
    def set_editable_project
      super(:id)
    end

    def redirect_without_project
      super(projects_path)
    end

    def project_params
      params[:project] ||= {}

      [:start_date, :end_date].each do |date|
        params[:project][date] = parse_date(params[:project][date])
      end

      params.require(:project).permit(
        :name, :description, :status, :start_date, :end_date
      )
    end

end
